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
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/SVGGraphics'
needs 'OLASimple/OLALib'
needs 'OLASimple/JobComments'

class Protocol
  include OLALib
  include OLAGraphics
  include FunctionalSVG
  include OLAKitIDs
  include OLAConstants
  include JobComments

  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'

  UNIT = 'S'
  OUTPUT_COMPONENT = ''
  PLASMA_LOCATION = 'fridge'
  SAMPLE_VOLUME = 350

  def main
    operations.make
    operations.each_with_index do |op, i|
      if debug
        op.temporary[OLAConstants::PATIENT_KEY] = "patientid#{i}"
        op.temporary[OLAConstants::KIT_KEY] = '001'
      else
        op.temporary[OLAConstants::PATIENT_KEY] = op.input(PATIENT_ID_INPUT).value
        op.temporary[OLAConstants::KIT_KEY] = op.input(KIT_ID_INPUT).value
      end
    end

    kit_groups = operations.group_by { |op| op.temporary[OLAConstants::KIT_KEY] }

    introduction
    record_technician_id
    safety_warning
    simple_clean("OLASimple")

    kit_groups.each do |kit_num, ops|
      next unless check_batch_size(ops)

      first_module_setup(ops, kit_num)
      set_output_components_and_units(ops, OUTPUT, OUTPUT_COMPONENT, UNIT)

      this_package = "#{kit_num}#{UNIT}"
      retrieve_package(this_package)
      package_validation_with_multiple_tries(this_package)
      open_package(this_package, ops)
      retrieve_plasma(ops)
      _, expected_plasma_samples = plasma_tubes(ops)
      sample_validation_with_multiple_tries(expected_plasma_samples)
      transfer_plasma(ops)
    end

    disinfect
    store
    cleanup
    wash_self
    accept_comments
    conclusion(operations)
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
      false
    else
      true
    end
  end

  def introduction
    show do
      title 'Welcome to OLASimple Sample Preparation'
      note 'In this protocol you will transfer a specific volume of patient plasma into barcoded sample tubes.'
    end
  end

  def safety_warning
    show do
      title 'Review the safety warnings'
      warning 'You will be working with infectious materials.'
      note 'Do <b>ALL</b> work in a biosafety cabinet (BSC)'
      note 'Always wear a lab coat and gloves for this protocol. We will use two layers of gloves for parts of this protocol.'
      note 'Make sure to use tight gloves. Tight gloves reduce the chance of the gloves getting caught on the tubes when closing their lids.'
      note 'Change your outer layer of gloves after touching any common space surface (such as a refrigerator door handle) as your gloves can now be contaminated by RNase or other previously amplified products that can cause false positives.'
      check 'Put on a lab coat and "doubled" gloves now.'
      note 'Throughout the protocol, please pay extra attention to the orange warning blocks.'
      warning 'Warning blocks can contain vital saftey information.'
    end
  end

  def retrieve_package(this_package)
    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the BSC"
      check 'Grab package'
      check 'Remove the <b>outside layer</b> of gloves (since you just touched the door knob).'
      check 'Put on a new outside layer of gloves.'
    end
  end

  def open_package(this_package, ops)
    show_open_package(this_package, '', 0) do
      img = kit_image(ops)
      check 'Check that the following are in the pack:'
      note display_svg(img, 0.75)
    end
  end

  def kit_image(ops)
    tubes, = kit_tubes(ops)
    grid = SVGGrid.new(tubes.size, 1, 80, 100)
    tubes.each_with_index do |svg, i|
      grid.add(svg, i, 0)
    end
    SVGElement.new(children: [grid], boundx: 1000, boundy: 300)
  end

  def retrieve_plasma(ops)
    tubes, plasma_ids = plasma_tubes(ops)
    grid = SVGGrid.new(tubes.size, 1, 250, 100)
    tubes.each_with_index do |svg, i|
      grid.add(svg, i, 0)
    end
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate(100, 0)
    show do
      title 'Retrieve Plasma samples'
      note "Retrieve plasma samples labeled #{plasma_ids.to_sentence.bold}."
      note "Patient samples are located in the #{PLASMA_LOCATION.bold}."
      note display_svg(img, 0.75)
    end
  end

  def transfer_plasma(ops)
    from_tubes, from_names = plasma_tubes(ops)
    to_tubes, to_names = kit_tubes(ops)
    ops.each_with_index do |_op, i|
      transfer_img = make_transfer(from_tubes[i], to_tubes[i], 300, "#{SAMPLE_VOLUME}ul", "(#{P1000_PRE})").translate(100, 0)
      show do
        title "Transfer #{from_names[i]} to #{to_names[i]}"
        note "Use a #{P1000_PRE} pipette and set it to <b>[3 5 0]</b>."
        check "Transfer <b>#{SAMPLE_VOLUME}uL</b> from <b>#{from_names[i]}</b> to <b>#{to_names[i]}</b> using a #{P1000_PRE} pipette."
        note display_svg(transfer_img, 0.75)
      end
    end
  end

  def store
    show do
      title 'Store Items'
      sample_tubes = sample_labels.map { |s| "#{UNIT}-#{s}" }
      note "Store <b>#{sample_tubes.to_sentence}</b> in the fridge on a cold rack."
    end
  end

  def cleanup
    show do
      title 'Clean Biosafety Cabinet (BSC)'
      note 'Place items in the BSC off to the side.'
      note 'Spray surface of BSC with 10% bleach. Wipe clean using paper towel.'
      note 'Spray surface of BSC with 70% ethanol. Wipe clean using paper towel.'
    end
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'You may start the next protocol immediately.'
    end
  end

  def kit_tubes(ops)
    tube_names = ops.map { |op| "#{UNIT}-#{op.temporary[OLAConstants::SAMPLE_KEY]}" }
    tubes = []
    tube_names.each_with_index do |s, _i|
      tubes << draw_svg(:roundedtube, svg_label: s.split('-').join("\n"), opened: false, contents: 'empty')
    end
    [tubes, tube_names]
  end

  def plasma_tubes(ops)
    plasma_ids = ops.map { |op| op.temporary[OLAConstants::PATIENT_KEY] }
    tubes = []
    plasma_ids.each_with_index do |s, _i|
      tubes << draw_svg(:roundedtube, svg_label: "\n\n\n" + s, opened: false, contents: 'full')
    end
    [tubes, plasma_ids]
  end

  def sample_labels
    operations.map { |op| op.temporary[OLAConstants::SAMPLE_KEY] }
  end
end

```
