# OLASimple Sample Preparation

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.


### Parameters

- **Patient Sample Identifier** 
- **Kit Identifier** 

### Outputs


- **Patient Sample** [S]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA plasma")'>OLA plasma</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
eval Library.find_by_name("OLAScheduling").code("source").content
extend OLAScheduling

def precondition(_op)
  if _op.plan && _op.plan.status != 'planning'
    schedule_same_kit_ops(_op)
  end
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# frozen_string_literal: true

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAKitIDs'
class Protocol
  include OLAKitIDs
  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'

  UNIT = 'S'
  OUTPUT_COMPONENT = ''

  def main
    operations.make
    operations.each do |op|
      if debug
        op.temporary[OLAConstants::PATIENT_KEY] = 'a patient id'
        op.temporary[OLAConstants::KIT_KEY] = '001'
      else
        op.temporary[OLAConstants::PATIENT_KEY] = op.input(PATIENT_ID_INPUT).value
        op.temporary[OLAConstants::KIT_KEY] = op.input(KIT_ID_INPUT).value
      end
    end

    kit_groups = operations.group_by { |op| op.temporary[OLAConstants::KIT_KEY] }

    kit_groups.each do |kit_num, ops|
      first_module_setup(ops, kit_num)
      set_output_components_and_units(ops, OUTPUT, OUTPUT_COMPONENT, UNIT)
    end

    operations.running.each do |op|
      show do
        title 'Put barcodes on things and stuff'
        note "Operation #{op.id}"
        note "PATIENT_KEY: #{op.temporary[OLAConstants::PATIENT_KEY]}"
        note "KIT_KEY: #{op.temporary[OLAConstants::KIT_KEY]}"
        note "SAMPLE_KEY: #{op.temporary[OLAConstants::SAMPLE_KEY]}"
      end
    end
    {}
  end

  # Since this is the first protocol in the workflow, we
  # pause here to link the incoming patient ids to the kit sample numbers
  # in a coherent and deterministic way.
  #
  # Makes the assumptions that all operations here are from the same kit
  # with output items made, and have a suitable batch size
  def first_module_setup(ops, kit_num)
    check_batch_size(ops)
    assign_sample_aliases_from_kit_id(ops, kit_num)

    data_associations = []
    ops.each do |op|
      output_item = op.output(OUTPUT).item
      data_associations << output_item.associate(OLAConstants::KIT_KEY, op.temporary[OLAConstants::KIT_KEY])
      data_associations << output_item.associate(OLAConstants::SAMPLE_KEY, op.temporary[OLAConstants::SAMPLE_KEY])
      data_associations << output_item.associate(OLAConstants::PATIENT_KEY, op.temporary[OLAConstants::PATIENT_KEY])
    end

    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end

  # Assigns sample aliases in order of patient id. each operation must have op.temporary[:patient] set.
  # Sample alias assignment is placed in op.temporary[:sample_num] for each op.
  #
  # requires that "operations" input only contains operations from a single kit
  def assign_sample_aliases_from_kit_id(operations, kit_id)
    operations = operations.sort_by { |op| op.temporary[OLAConstants::PATIENT_KEY] }
    sample_nums = sample_nums_from_kit_num(extract_kit_number(kit_id))
    operations.each_with_index do |op, i|
      op.temporary[OLAConstants::SAMPLE_KEY] = sample_num_to_id(sample_nums[i])
    end
  end

  def check_batch_size(ops)
    if ops.size > OLAConstants::BATCH_SIZE
      ops.each do |op|
        op.error(:batch_size_too_big, "operations.size operations batched with #{kit_num}, but max batch size is #{BATCH_SIZE}.")
      end
      return
    end
  end
end

```
