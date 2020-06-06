# OLASimple RNA Extraction

Blood CD4+ cells are negatively selected and lysed. Magnetic beads and antibodies are used to separate unwanted cells.
### Inputs


- **Plasma** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA plasma")'>OLA plasma</a>



### Outputs


- **Viral RNA** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA viral RNA")'>OLA viral RNA</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
eval Library.find_by_name("OLAScheduling").code("source").content
extend OLAScheduling

BATCH_SIZE = 2
def precondition(op)
  schedule_same_kit_ops(op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# frozen_string_literal: true

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments
  include OLAKitIDs
  include FunctionalSVG

  ##########################################
  # INPUT/OUTPUT
  ##########################################

  INPUT = 'Plasma'
  OUTPUT = 'Viral RNA'

  ##########################################
  # COMPONENTS
  ##########################################

  AREA = PRE_PCR
  BSC = 'BSC'
  ETHANOL = 'molecular grade ethanol'
  GuSCN_WASTE = 'GuSCN waste container'

  PACK_HASH = EXTRACTION_UNIT

  THIS_UNIT     = PACK_HASH['Unit Name']
  DTT           = THIS_UNIT + PACK_HASH['Components']['dtt']
  LYSIS_BUFFER  = THIS_UNIT + PACK_HASH['Components']['lysis buffer']
  WASH1         = THIS_UNIT + PACK_HASH['Components']['wash buffer 1']
  WASH2         = THIS_UNIT + PACK_HASH['Components']['wash buffer 2']
  SA_WATER      = THIS_UNIT + PACK_HASH['Components']['sodium azide water']
  SAMPLE_COLUMN = THIS_UNIT + PACK_HASH['Components']['sample column']
  RNA_EXTRACT   = THIS_UNIT + PACK_HASH['Components']['rna extract tube']

  KIT_SVGs = {
    DTT => :roundedtube,
    LYSIS_BUFFER => :roundedtube,
    SA_WATER => :roundedtube,
    WASH1 => :screwbottle,
    WASH2 => :screwbottle,
    SAMPLE_COLUMN => :samplecolumn,
    RNA_EXTRACT => :tube
  }.freeze
  INPUT_SVG = :roundedtube

  SHARED_COMPONENTS = [DTT, WASH1, WASH2, SA_WATER].freeze
  PER_SAMPLE_COMPONENTS = [LYSIS_BUFFER, SAMPLE_COLUMN, RNA_EXTRACT].freeze
  OUTPUT_COMPONENT = '6'

  CENTRIFUGE_TIME = '1 minute'

  # for debugging
  PREV_COMPONENT = 'S'
  PREV_UNIT = ''

  def main
    this_package = prepare_protocol_operations

    introduction
    record_technician_id
    safety_warning
    required_equipment
    simple_clean("OLASimple RNA Extraction")

    retrieve_inputs
    kit_num = extract_kit_number(this_package)

    expected_inputs = sample_labels.map {|s| "#{THIS_UNIT}#{s}"}
    sample_validation_with_multiple_tries(expected_inputs)

    retrieve_package(this_package)
    package_validation_with_multiple_tries(this_package)
    open_package(this_package)

    prepare_buffers
    lyse_samples
    add_ethanol

    3.times do
      operations.each { |op| add_sample_to_column(op) }
      centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}")
    end
    change_collection_tubes

    add_wash_1
    centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}")
    change_collection_tubes

    add_wash_2
    centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}")

    transfer_column_to_e6
    elute
    incubate(sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }, '1 minute')
    centrifuge_columns(flow_instructions: '<b>DO NOT DISCARD FLOW THROUGH</b>')

    finish_up
    disinfect
    store
    cleanup
    wash_self
    accept_comments
    conclusion(operations)
    {}
  end

  # perform initiating steps for operations,
  # and gather kit package from operations
  # that will be used for this protocol.
  # returns kit package if nothing went wrong
  def prepare_protocol_operations
    if operations.length > BATCH_SIZE
      raise "Batch size > #{BATCH_SIZE} is not supported for this protocol. Please rebatch."
    end

    operations.make.retrieve interactive: false

    if debug
      labels = %w[001 002]
      operations.each.with_index do |op, i|
        op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
        op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
        op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
        op.input(INPUT).item.associate(KIT_KEY, '001')
        op.input(INPUT).item.associate(PATIENT_KEY, 'a patient id')
      end
    end
    save_temporary_input_values(operations, INPUT)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)

    operations.each do |op|
      op.make_item_and_alias(OUTPUT, 'rna extract tube', INPUT)
    end

    kits = operations.running.group_by { |op| op.temporary[:input_kit] }
    this_package = kits.keys.first + THIS_UNIT
    raise 'More than one kit is not supported by this protocol. Please rebatch.' if kits.length > 1

    this_package
  end

  def sample_labels
    operations.map { |op| op.temporary[:input_sample] }
  end

  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end

  def introduction
    show do
      title 'Welcome to OLASimple RNA Extraction'
      note 'In this protocol you will lyse and purify RNA from HIV-infected plasma.'
      note 'RNA is prone to degradation by RNase present in our eyes, skin, and breath. Avoid opening tubes outside the Biosafety Cabinet (BSC).'
      check 'Before starting this protocol, make sure you have access to molecular grade ethanol (~10 mL). Do not use other grades of ethanol as this will negatively affect the RNA extraction yield.'
    end
  end

  def safety_warning
    show do
      title 'Review the safety warnings'
      warning 'You will be working with infectious materials.'
      warning "Do not mix #{LYSIS_BUFFER} or #{WASH1} with bleach, as this will generate toxic cyanide gas. #{LYSIS_BUFFER} AND #{WASH1} waste must be discarded appropriately based on guidelines for GuSCN handling waste"
      note 'Use tight gloves. Tight gloves help reduce chances for your gloves to be trapped when closing the tubes which can increase contamination risk.'
      note "Do <b>ALL</b> work in a biosafety cabinet (#{BSC.bold})"
      note 'Always wear a lab coat and gloves for this protocol. We will use two layers of gloves for parts of this protocol.'
      note 'Change outer gloves after touching any common surface (such as a refrigerator door handle) as your gloves now can be contaminated by RNase or other previously amplified products that can cause false positives.'
      check 'Put on a lab coat and "doubled" gloves now.'
      note 'Throughout the protocol, please pay extra attention to the orange warning blocks.'
      warning 'Warning blocks can contain vital saftey information.'
    end
  end

  def required_equipment
    show do
      title 'Get required equipment'
      note "You will need the following equipment in the #{BSC.bold}"
      materials = [
        'P1000 pipette and filter tips',
        'P200 pipette and filter tips',
        'P20 pipette and filter tips',
        'Vortex mixer',
        'Cold tube rack',
        'Timer',
        'Bleach in a beaker',
        '70% v/v ethanol',
        'Molecular grade ethanol'
      ]
      materials.each do |m|
        check m
      end
    end
  end

  def retrieve_package(this_package)
    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{BSC}"
      check 'Grab package'
      check 'Remove the <b>outside layer</b> of gloves (since you just touched the door knob).'
      check 'Put on a new outside layer of gloves.'
    end
  end

  def open_package(this_package)
    show_open_package(this_package, '', 0) do
      img = kit_image
      check 'Check that the following are in the pack:'
      note display_svg(img, 0.75)
      note 'Arrange tubes on plastic rack for later use.'
    end
  end

  def kit_image
    grid = SVGGrid.new(PER_SAMPLE_COMPONENTS.size + SHARED_COMPONENTS.size, operations.size, 80, 100)
    initial_contents = {
      DTT => 'full',
      LYSIS_BUFFER => 'full',
      SA_WATER => 'full',
      WASH1 => 'full',
      WASH2 => 'full',
      SAMPLE_COLUMN => 'empty',
      RNA_EXTRACT => 'empty'
    }

    SHARED_COMPONENTS.each_with_index do |component, i|
      svg = draw_svg(KIT_SVGs[component], svg_label: component, opened: false, contents: initial_contents[component])
      grid.add(svg, i, 0)
    end

    operations.each_with_index do |op, i|
      sample_num = op.temporary[:output_sample]
      PER_SAMPLE_COMPONENTS.each_with_index do |component, j|
        svg = draw_svg(KIT_SVGs[component], svg_label: "#{component}\n#{sample_num}", opened: false, contents: initial_contents[component])
        svg.translate!(30 * (i % 2), 0)
        grid.add(svg, j + SHARED_COMPONENTS.size, i)
      end
    end
    grid.align!('center-left')
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate!(30, 50)
  end

  def retrieve_inputs
    input_sample_ids = operations.map do |op|
      op.input_ref(INPUT)
    end

    grid = SVGGrid.new(input_sample_ids.size, 1, 80, 100)
    input_sample_ids.each_with_index do |s, i|
      svg = draw_svg(INPUT_SVG, svg_label: s.split('-').join("\n"), opened: false, contents: 'full')
      grid.add(svg, i, 0)
    end

    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 200).translate!(0, -30)
    show do
      title 'Retrieve Samples'
      note display_svg(img, 0.75)
      check "Take #{input_sample_ids.to_sentence} from #{FRIDGE_PRE}"
    end
  end

  # helper method for simple transfers in this protocol
  def transfer_and_vortex(title, from, to, volume_ul, warning: nil, to_contents: 'empty', to_svg_override: nil, from_svg_override: nil)
    pipette, extra_note = pipette_decision(volume_ul)

    from_component, from_sample_num = from.split('-')
    to_component, to_sample_num = to.split('-')
    from_svg = from_svg_override || KIT_SVGs[from_component]
    to_svg = to_svg_override || KIT_SVGs[to_component]
    if from_svg && to_svg
      from_label = [from_component, from_sample_num].join("\n")
      from_svg = draw_svg(from_svg, svg_label: from_label, opened: true, contents: 'full')
      to_label = [to_component, to_sample_num].join("\n")
      to_svg = draw_svg(to_svg, svg_label: to_label, opened: true, contents: to_contents)
      img = make_transfer(from_svg, to_svg, 300, "#{volume_ul}ul", "(#{pipette})")
    end

    show do
      title title
      check "Transfer <b>#{volume_ul}uL</b> of <b>#{from}</b> into <b>#{to}</b> using a #{pipette} pipette."
      note extra_note if extra_note
      warning warning if warning
      note display_svg(img, 0.75) if img
      check 'Discard pipette tip.'
      check "Vortex <b>#{to}</b> for <b>2 seconds, twice</b>."
      check "Centrifuge <b>#{to}</b> for <b>5 seconds</b>."
    end
  end

  def pipette_decision(volume_ul)
    if volume_ul <= 20
      P20_PRE
    elsif volume_ul <= 200
      P200_PRE
    elsif volume_ul <= 1000
      P1000_PRE
    else
      factor = volume_ul.fdiv(1000).ceil
      split_volume = volume_ul.fdiv(factor)
      [P1000_PRE, "Split transfer into <b>#{factor}</b> seperate transfers of <b>#{split_volume}uL</b>."]
    end
  end

  # helper method for simple incubations
  def incubate(samples, time)
    show do
      title 'Incubate Sample Solutions'
      note "Let <b>#{samples.to_sentence}</b> incubate for <b>#{time}</b> at room temperature."
      check "Set a timer for <b>#{time}</b>"
      note "Do not proceed until time has elapsed."
    end
  end

  def centrifuge_columns(flow_instructions: nil)
    columns = sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }

    show do
      title " Centrifuge Columns for #{CENTRIFUGE_TIME}"
      warning 'Ensure both tube caps are closed'
      raw centrifuge_proc('Column', columns, CENTRIFUGE_TIME, '', AREA)
      check flow_instructions if flow_instructions
    end
  end

  def prepare_buffers
    # add sa water to dtt/trna
    transfer_and_vortex(
      "Prepare #{DTT}",
      SA_WATER,
      DTT,
      25,
      to_contents: 'full'
    )

    # add dtt solution to lysis buffer
    operations.each do |op|
      transfer_and_vortex(
        "Prepare #{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        DTT,
        "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        10,
        to_contents: 'full'
      )
    end

    # prepare wash buffer 2 with ethanaol
    transfer_and_vortex(
      "Prepare #{WASH2}",
      ETHANOL,
      WASH2,
      1600,
      warning: 'Do not use other grades of ethanol.',
      to_contents: 'full'
    )
  end

  # transfer plasma Samples into lysis buffer and incubate
  def lyse_samples
    operations.each do |op|
      transfer_and_vortex(
        "Lyse Sample #{op.input_ref(INPUT)}",
        op.input_ref(INPUT).to_s,
        "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        300,
        to_contents: 'full',
        from_svg_override: INPUT_SVG
      )
    end

    lysed_samples = operations.map { |op| "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}" }
    incubate(lysed_samples, '15 minutes')
  end

  def add_ethanol
    operations.each do |op|
      transfer_and_vortex(
        "Add Buffer Ethanol to #{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        ETHANOL,
        "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        1200,
        to_contents: 'full'
      )
    end
  end

  def add_sample_to_column(op)
    from = "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}"
    to = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
    transfer_carefully(from, to, 500, from_type: 'sample', to_type: 'column', to_contents: 'empty')
  end

  def change_collection_tubes
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}" }
    show do
      title 'Change Collection Tubes'
      sample_columns.each do |column|
        check "Transfer <b>#{column}</b> to a new collection tube."
      end
      note 'Discard previous collection tubes.'
    end
  end

  def add_wash_1
    sample_columns = operations.each do |op|
      column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
      transfer_carefully(WASH1, column, 500, from_type: 'buffer', to_type: 'column', to_contents: 'full')
    end
  end

  def add_wash_2
    sample_columns = operations.each do |op|
      column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
      transfer_carefully(WASH2, column, 500, from_type: 'buffer', to_type: 'column', to_contents: 'full')
    end
  end

  def transfer_carefully(from, to, volume_ul, from_type: nil, to_type: nil, to_contents: nil)
    pipette, extra_note = pipette_decision(volume_ul)

    from_component = from.split('-')[0]
    to_component = to.split('-')[0]

    img = nil
    if KIT_SVGs[from_component] && KIT_SVGs[to_component]
      from_label = from.split('-').join("\n")
      from_svg = draw_svg(KIT_SVGs[from_component], svg_label: from_label, opened: true, contents: 'full')
      to_label = to.split('-').join("\n")
      to_svg = draw_svg(KIT_SVGs[to_component], svg_label: to_label, opened: true, contents: to_contents)
      img = make_transfer(from_svg, to_svg, 300, "#{volume_ul}ul", "(#{pipette})")
    end
    show do
      title "Add #{from_type || from} to #{to_type || to}"
      note "<b>Carefully</b> open #{to_type} <b>#{to}</b> lid."
      check "<b>Carefully</b> Add <b>#{volume_ul}uL</b> of #{from_type} <b>#{from}</b> to <b>#{to}</b> using a #{pipette} pipette."
      note extra_note if extra_note
      note display_svg(img, 0.75) if img
      check 'Discard pipette tip.'
      note "<b>Slowly</b> close lid of <b>#{to}</b>"
    end
  end

  def transfer_column_to_e6
    show do
      title 'Transfer Columns'
      warning 'Make sure the bottom of the E5 and E6 columns did not touch any fluid from the previous collection tubes. When in doubt, replace collection tubes again and centrifuge for 1 more minute .'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:output_sample]}"
        check "Transfer column <b>#{column}</b> to <b>#{extract_tube}</b>"
      end
    end
  end

  def elute
    show do
      title 'Add Elution Buffer'
      warning 'Add buffer to center of columns'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
        check "Add <b>60uL</b> from <b>#{SA_WATER}</b> to column <b>#{column}</b>"
      end
    end
  end

  def finish_up
    show do
      title 'Prepare Samples for Storage'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:output_sample]}"
        check "Remove column <b>#{column}</b> from <b>#{extract_tube}</b>, and discard <b>#{column} in #{WASTE_PRE}</b>"
      end
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}" }
      check "Place <b>#{extract_tubes.to_sentence}</b> on cold rack"
    end
  end

  def store
    show do
      title 'Store Items'
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}" }
      note "Store <b>#{extract_tubes.to_sentence}</b> in the fridge on a cold rack if the amplification module will proceed immediately."
      note "Store <b>#{extract_tubes.to_sentence}</b> in -20C freezer if proceeding with the amplification module later."
    end
  end

  def cleanup
    show do
      title 'Clean up Waste'
      warning "DO NOT dispose of liquid waste and bleach into #{GuSCN_WASTE}, this can produce dangerous gas."
      bullet 'Dispose of liquid waste in bleach down the sink with running water.'
      bullet "Dispose of remaining tubes into #{WASTE_PRE}."
      bullet "Dispose of #{GuSCN_WASTE} in <a special way that we haven't figured out yet.>"
    end

    show do
      title 'Clean Biosafety Cabinet (BSC)'
      note 'Place items in the BSC off to the side.'
      note 'Spray surface of BSC with 10% bleach. Wipe clean using paper towel.'
      note 'Spray surface of BSC with 70% ethanol. Wipe clean using paper towel.'
      note "After cleaning, dispose of gloves and paper towels in #{WASTE_PRE}."
    end
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'You may start the next protocol immediately.'
    end
  end
end

```
