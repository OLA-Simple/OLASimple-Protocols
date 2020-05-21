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
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAKitIDs'
class Protocol
  include OLAKitIDs
  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'

  UNIT = "S"
  OUTPUT_COMPONENT = "S"

  def main
    operations.make
    operations.each do |op|
      if debug
        op.temporary[OLAConstants::PATIENT_KEY] = "a patient id"
        op.temporary[OLAConstants::KIT_KEY] = "001"
      else
        op.temporary[OLAConstants::PATIENT_KEY] = op.input(PATIENT_ID_INPUT).value
        op.temporary[OLAConstants::KIT_KEY] = op.input(KIT_ID_INPUT).value
    end
    end
    
    kit_groups = operations.group_by { |op| op.temporary[OLAConstants::KIT_KEY] }
    
    kit_groups.each do |kit_num, ops|
      first_module_setup(ops, kit_num)
    end

    show do
      title 'Put barcodes on things and stuff'
      note "yes"
    end

    {}

  end
  
  # Since this is the first protocol in the workflow, we
  # pause here to link the incoming patient ids to the kit sample numbers
  # in a coherent and deterministic way.
  #
  # Makes the assumptions that all operations here are from the same kit
  # with output items made, and have a suitable batch size
  def first_module_setup(operations, kit_num)
    assign_sample_aliases_from_kit_id(operations, kit_num)

    data_associations = []
    operations.each do |op|
      new_das = set_kit_information_lazy(
        op.output(OUTPUT).item,
        kit_num: op.temporary[OLAConstants::KIT_KEY], 
        sample_num: op.temporary[OLAConstants::SAMPLE_KEY], 
        patient: op.temporary[OLAConstants::PATIENT_KEY]
      )
      data_associations.concat(new_das)
    end
    
    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end

end

```
