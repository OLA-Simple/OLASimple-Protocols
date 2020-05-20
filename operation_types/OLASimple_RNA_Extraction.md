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
needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"
needs "OLASimple/JobComments"
needs "OLASimple/OLAKitIDs"

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments
  include OLAKitIDs

  ##########################################
  # INPUT/OUTPUT
  ##########################################

  INPUT = "Plasma"
  OUTPUT = "Viral RNA"

  ##########################################
  # COMPONENTS
  ##########################################

  AREA = PRE_PCR
  BSC = "BSC"
  ETHANOL = "molecular grade ethanol"
  


  PACK_HASH = {
            "Unit Name" => "E",
            "Components" => {
                "DTT/tRNA" => "E0",
                "Lysis buffer" => "E1",
                "Wash 1" => "E2",
                "Wash 2" => "E3",
                "sodium azide water" => "E4",
                "Sample column" => "E5",
                "Extract tube" => "E6"
            },
            "Number of Samples" => 2,
        }

  INCOMING_SAMPLE = "S"

  DTT = "E0"
  LYSIS_BUFFER = "E1"
  WASH1 = "E2"
  WASH2 = "E3"
  SA_WATER= "E4"
  SAMPLE_COLUMN = "E5"
  RNA_EXTRACT = "E6"
  
  GuSCN_WASTE = "GuSCN waste container"
  
  KIT_SVGs = {
    INCOMING_SAMPLE => :roundedtube,
    DTT => :roundedtube,
    LYSIS_BUFFER => :roundedtube,
    SA_WATER => :roundedtube,
    WASH1 => :screwbottle,
    WASH2 => :screwbottle,
    SAMPLE_COLUMN => :samplecolumn,
    RNA_EXTRACT => :tube,
  }
  
  SHARED_COMPONENTS = [DTT, WASH1, WASH2, SA_WATER]
  PER_SAMPLE_COMPONENTS = [LYSIS_BUFFER, SAMPLE_COLUMN, RNA_EXTRACT]

  THIS_UNIT = "E"

  CENTRIFUGE_TIME = "1 minute"

  def main

    this_package = prepare_protocol_operations

    introduction
    record_technician_id
    safety_warning
    required_equipment
    
    retrieve_inputs
    kit_num = extract_kit_number(this_package)
    sample_validation_with_multiple_tries(kit_num)
    
    retrieve_and_open_package(this_package)
    
    prepare_buffers
    lyse_samples
    add_ethanol

    3.times do
      operations.each { |op| add_sample_to_column(op) }
      centrifuge_columns(flow_instructions: "Discard flow through into " + GuSCN_WASTE)
    end
    change_collection_tubes

    add_buffer_e2
    centrifuge_columns(flow_instructions: "Discard flow through into " + GuSCN_WASTE)
    change_collection_tubes
    
    add_buffer_e3
    centrifuge_columns(flow_instructions: "Discard flow through into " + GuSCN_WASTE)
    change_collection_tubes

    transfer_column_to_e6
    elute
    incubate(sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }, "1 minute")
    centrifuge_columns(flow_instructions: "<b>DO NOT DISCARD FLOW THROUGH</b>")

    finish_up
    disinfect
    store
    cleanup

    accept_comments
    return {}
  end

  # perform initiating steps for operations, 
  # and gather kit package from operations
  # that will be used for this protocol.
  # returns kit package if nothing went wrong
  def prepare_protocol_operations
    if operations.length > BATCH_SIZE
      raise "Batch size > #{BATCH_SIZE} is not supported for this protocol. Please rebatch."
    end
    operations.retrieve interactive: false
    save_user operations

    operations.each.with_index do |op, i|
      kit_num = op.input(INPUT).item.get(KIT_KEY)
      patient_id = op.input(INPUT).item.get(PATIENT_ID_KEY)
      sample_alias = op.input(INPUT).item.get(SAMPLE_KEY)
      if debug && kit_num.nil? && patient_id.nil? && sample_alias.nil?
        patient_id = rand(1..30)      
        kit_num = 1.to_s.rjust(3, "0")
        sample_alias = (i + 1).to_s.rjust(3, "0")
      end
      op.temporary[:input_kit] = kit_num
      op.temporary[:patient] = patient_id
      op.temporary[:input_sample] = sample_alias

      if op.temporary[:input_kit].nil?
        raise "Input kit number cannot be nil"
      end
    end

    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end

    save_temporary_output_values(operations.running)
    packages = group_packages(operations.running)
    this_package = packages.keys.first
    if packages.length > 1
        raise "More than one kit is not supported by this protocol. Please rebatch." 
    end
    
    operations.running.each do |op|
      op.make_item_and_alias(OUTPUT, "Extract tube", INPUT)
    end
    this_package
  end

  def sample_labels
    operations.map { |op| op.temporary[:input_sample] }
  end

  def save_user ops
    ops.each do |op|
      username = get_technician_name(self.jid)
      op.associate(:technician, username)
    end
  end

  def introduction
    show do
      title "Welcome to OLASimple RNA Extraction"
      check "Put on tight gloves. Tight gloves help reduce chances for your gloves to be trapped when closing the tubes which can increase contamination risk."
      note "In this protocol you will lyse and purify RNA from HIV-infected plasma."
      check "OLA RNA Extraction is sensitive to contamination. Small contamination from the previously amplified products can cause false positives. Before proceeding, wipe the space and pipettes with 10% bleach (freshly prepared or prepared daily) and 70% ethanol using paper towels."
      note "RNA is prone to degradation by RNase present in our eyes, skin, and breath. Avoid opening tubes outside the Biosafety Cabinet (BSC)."
      note "Change gloves after touching any common surface (such as a refrigerator door handle) as your gloves now can be contaminated by RNase or other previously amplified products that can cause false positives."
      check "Before starting this protocol, make sure you have access to molecular grade ethanol (~10 mL). Do not use other grades of ethanol as this will negatively affect the RNA extraction yield."

    end

  end

  def safety_warning
    show do
      title "Review the safety warnings"
      warning "You will be working with infectious materials."
      note "Do <b>ALL</b> work in a biosafety cabinet (#{BSC.bold})"
      note "Always wear a lab coat and gloves for this protocol."
      warning "Do not mix #{LYSIS_BUFFER} or #{WASH1} with bleach, as this will generate toxic cyanide gas. #{LYSIS_BUFFER} AND #{WASH1} waste must be discarded appropriately based on guidelines for GuSCN handling waste"
      check "Put on a lab coat and \"doubled\" gloves now."
    end
  end

  def required_equipment
    show do
      title "Get required equipment"
      note "You will need the following equipment in the #{BSC.bold}"
      materials = [
          "P1000 pipette and filter tips",
          "P200 pipette and filter tips",
          "P20 pipette and filter tips",
          "Vortex mixer",
          "Cold tube rack",
          "Timer",
          "Bleach in a beaker",
          "70% v/v ethanol",
          "Molecular grade ethanol"
      ]
      materials.each do |m|
        check m
      end
    end
  end
  
  def retrieve_and_open_package(this_package)
    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{BSC}"
      check "Grab package"
      check "Remove the <b>outside layer</b> of gloves (since you just touched the door knob)."
      check "Put on a new outside layer of gloves."
    end
    
    show_open_package(this_package, "", 0) do
      img = kit_image
      check "Check that the following are in the pack:"
      note display_svg(img, 0.75)
      note "Arrange tubes on plastic rack for later use."
    end
  end
  
  def kit_image
    grid = SVGGrid.new(PER_SAMPLE_COMPONENTS.size + SHARED_COMPONENTS.size, operations.size, 80, 100)

    initial_contents = {
      INCOMING_SAMPLE => 'full',
      DTT => 'full',
      LYSIS_BUFFER => 'full',
      SA_WATER => 'full',
      WASH1 => 'full',
      WASH2 => 'full',
      SAMPLE_COLUMN => 'empty',
      RNA_EXTRACT => 'empty',
    }
    
    SHARED_COMPONENTS.each_with_index do |component, i|
      svg = draw_svg(KIT_SVGs[component], svg_label: component, opened: false, contents: initial_contents[component])
      grid.add(svg, i, 0)
    end

    operations.each_with_index do |op, i|
      sample_num = op.temporary[:input_sample]
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
    input_samples = sample_labels.map {  |s| "#{INCOMING_SAMPLE}-#{s}" }
    
    grid = SVGGrid.new(input_samples.size, 1, 80, 100)
    input_samples.each_with_index do |s,i|
      svg = draw_svg(KIT_SVGs[INCOMING_SAMPLE], svg_label: s.split('-').join("\n"), opened: false, contents: 'full')
      grid.add(svg, i, 0)
    end
    
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 200).translate!(0, -30)
    show do
      title "Retrieve Samples"
      note display_svg(img, 0.75)
      check "Take #{input_samples.to_sentence} from #{FRIDGE_PRE}"
    end
  end
  
  # helper method for simple transfers in this protocol
  def transfer_and_vortex(title, from, to, volume_ul, warning: nil, to_contents: 'empty')
    from_component, from_sample_num = from.split('-')
    to_component, to_sample_num = to.split('-')
    
    if KIT_SVGs[from_component] && KIT_SVGs[to_component]
      from_label = [from_component, from_sample_num].join("\n")
      from_svg = draw_svg(KIT_SVGs[from_component], svg_label: from_label, opened: true, contents: 'full')
      to_label = [to_component, to_sample_num].join("\n")
      to_svg = draw_svg(KIT_SVGs[to_component], svg_label: to_label, opened: true, contents: to_contents)
      img = make_transfer(from_svg, to_svg, 250, "#{volume_ul}ul", "(#{pipette_decision(volume_ul)})")
    end
    
    show do
      title title
      check "Transfer <b>#{volume_ul}</b> of <b>#{from}</b> into <b>#{to}</b> using a #{pipette_decision(volume_ul)} pipette."
      warning warning if warning
      note display_svg(img, 0.75) if img
      check 'Discard pipette tip.'
      check "Vortex <b>#{to}</b> for <b>2 seconds, twice</b>."
      check "Centrifuge <b>#{to}</b> for <b>5 seconds</b>."
    end
  end
  
  def pipette_decision(volume_ul)
    if volume_ul <= 20
      return P20_PRE
    elsif volume_ul <= 200
      return P200_PRE
    else
      return P1000_PRE
    end
  end

  # helper method for simple incubations
  def incubate(samples, time)
    show do
      title 'Incubate Sample Solutions'
      note "Let <b>#{samples.to_sentence}</b> incubate for <b>#{time}</b> at room temperature."
      check "Set a timer for <b>#{time}</b>"
    end
  end

  def centrifuge_columns(flow_instructions: nil)
    columns = sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}"}
    
    show do
      title " Centrifuge Columns for #{CENTRIFUGE_TIME}"
      warning "Ensure both tube caps are closed"
      raw centrifuge_proc("Column", columns, CENTRIFUGE_TIME, "", AREA)
      check flow_instructions if flow_instructions
    end
  end

  def prepare_buffers
    # add sa water to dtt/trna
    show do
      title "Prepare #{DTT}"
      note 'In the next few instructions, we will prepare the buffers used for the extraction.'      
      check "Transfer <b>25ul</b> of <b>#{SA_WATER}</b> into <b>#{DTT}</b>."
      check 'Discard pipette tip.'
      check "Vortex <b>#{DTT}</b> for <b>2 seconds twice</b>."
      check "Centrifuge <b>#{DTT}</b> for <b>5 seconds</b>."
    end

    # add dtt solution to lysis buffer
    operations.each do |op|
      transfer_and_vortex(
        "Prepare #{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        DTT, 
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
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
  
  SAMPLE_VOLUME = "300ul"
  # transfer plasma Samples into lysis buffer and incubate
  def lyse_samples
    operations.each do |op|
      transfer_and_vortex(
        'Lyse Samples', 
        "#{INCOMING_SAMPLE}-#{op.temporary[:input_sample]}",
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        300,
        to_contents: 'full'
      )
    end
    
    lysed_samples = operations.map { |op| "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}" }
    incubate(lysed_samples, "15 minutes")
  end

  def add_ethanol
    operations.each do |op|
      transfer_and_vortex(
        'Add Buffer Ethanol', 
        ETHANOL, 
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        1200,
        to_contents: 'full'
      )
    end
  end

  SAMPLE_TRANSFER_VOLUME = 800#ul
  def add_sample_to_column(op)
    from = "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}"
    to = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
    transfer_carefully(from, to, 500, from_type: 'sample', to_type: 'column', to_contents: 'empty')
  end

  def change_collection_tubes
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do
      title 'Change Collection Tubes'
      sample_columns.each do |column|
        check "Transfer <b>#{column}</b> to a new collection tube."
      end
      note "Discard previous collection tubes."
    end
  end

  def add_buffer_e2
    sample_columns = operations.each do |op| 
      column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
      transfer_carefully(WASH2, column, 500, from_type: 'buffer', to_type: 'column', to_contents: 'full')
    end
  end

  def add_buffer_e3
    sample_columns = operations.each do |op| 
      column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
      transfer_carefully(WASH2, column, 500, from_type: 'buffer', to_type: 'column', to_contents: 'full')
    end
  end
  
  def transfer_carefully(from, to, volume_ul, from_type: nil, to_type: nil, to_contents: nil)
    from_component = from.split('-')[0]
    to_component = to.split('-')[0]
    
    img = nil
    if KIT_SVGs[from_component] && KIT_SVGs[to_component]
      from_label = from.split('-').join("\n")
      from_svg = draw_svg(KIT_SVGs[from_component], svg_label: from_label, opened: true, contents: 'full')
      to_label = to.split('-').join("\n")
      to_svg = draw_svg(KIT_SVGs[to_component], svg_label: to_label, opened: true, contents: to_contents)
      img = make_transfer(from_svg, to_svg, 250, "#{volume_ul}ul", "(#{pipette_decision(volume_ul)})")
    end
    show do 
      title "Add #{from_type || from} to #{to_type || to}"
      note "<b>Carefully</b> open #{to_type} <b>#{to}</b> lid."
      check "<b>Carefully</b> Add <b>#{volume_ul}uL</b> of #{from_type} <b>#{from}</b> to <b>#{to}</b> using a #{pipette_decision(volume_ul)} pipette."
      note display_svg(img, 0.75) if img
      check 'Discard pipette tip.'
      note "<b>Slowly</b> close lid of <b>#{to}</b>"
    end
  end

  def transfer_column_to_e6
    show do
      title 'Transfer Columns'
      warning "Make sure the bottom of the E5 and E6 columns  did not touch any fluid from the previous collection tubes. When in doubt, centrifuge for 1 more minute and replace collection tubes again."
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:input_sample]}"
        check "Transfer <b>#{column}</b> to <b>#{extract_tube}</b>"
      end
    end
  end

  def elute
    show do 
      title 'Add Elution Buffer'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        check "Add <b>60uL</b> from <b>#{SA_WATER}</b> to <b>#{column}</b>"
      end
    end
  end

  def finish_up
    show do
      title "Prepare Samples for Storage"
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:input_sample]}"
        check "Remove column <b>#{column}</b> from <b>#{extract_tube}</b>, and discard <b>#{column} in #{WASTE_PRE}</b>"
      end
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}"}
      check "Place <b>#{extract_tubes.to_sentence}</b> on cold rack"
    end
  end

  def disinfect
    show do
      title 'Disinfect Items'
      check 'Spray and wipe down all reagent and sample tubes with bleach and ethanol.'
    end
  end

  def store
    show do
      title 'Store Items'
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}"}
      note "Store <b>#{extract_tubes.to_sentence}</b> in the fridge on a cold rack if the amplification module will be proceeded immediately."
      
      note "Store <b>#{extract_tubes.to_sentence}</b> in -20C freezer if proceeding with the amplification module later."
    end
  end

  def cleanup
    show do
      title "Clean up Waste"
      warning "Do not dispose of liquid waste and bleach in GuSCN waste, this can produce dangerous gas."
      bullet "Dispose of liquid waste in bleach down the sink with running water."
      bullet "Dispose of remaining tubes into #{WASTE_PRE}."
    end

    show do
      title "Clean Biosafety Cabinet (BSC)"
      note "Place items in the BSC off to the side."
      note "Spray surface of BSC with 10% bleach. Wipe clean using paper towel."
      note "Spray surface of BSC with 70% ethanol. Wipe clean using paper towel."
      note "After cleaning, dispose of gloves and paper towels in #{WASTE_PRE}."
    end
  end

  
  
  ####################################################################################
  #### SVGs                                                                       ####
  ####################################################################################
  def roundedtube(opened: false, contents: 'empty')
    _roundedtube = SVGElement.new(boundx: 46.92, boundy: 132.74)
    _roundedtube.add_child(
        '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2{fill:#fff;}.cls-2,.cls-3{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3{fill:none;}</style></defs><title>Untitled-18</title><path class="cls-1" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-2" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-3" d="M412.06,252" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,253.6a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,255.44a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M375.39,257.57v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H377.91A2.52,2.52,0,0,0,375.39,257.57Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
        ).translate!(0,70)
  end
  
  def screwbottle(opened: false, contents: 'empty')
    _screwbottle = SVGElement.new(boundx: 46.92, boundy: 132.74)
    _screwbottle.add_child(
        '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2,.cls-3{fill:none;}.cls-3,.cls-4{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-4{fill:#fff;}</style></defs><path class="cls-1" d="M377.92,325.7c-4.23-1-8.46.27-11.89,2v31.86a8.73,8.73,0,0,0,8.71,8.71h41.68a8.73,8.73,0,0,0,8.71-8.71V328.25c-9.24.24-7.87,3.46-19.44,7.63S387.64,328,377.92,325.7Z" transform="translate(-365.78 -243.8)"/><path class="cls-2" d="M369,280.29" transform="translate(-365.78 -243.8)"/><rect class="cls-3" x="0.25" y="43.66" width="59.09" height="80.08" rx="8.6" ry="8.6"/><path class="cls-4" d="M395.58,244c-16.32,0-29.55,3.59-29.55,8V285.6c0,4.42,13.23,8,29.55,8s29.55-3.59,29.55-8V252.05C425.12,247.63,411.89,244,395.58,244Z" transform="translate(-365.78 -243.8)"/><ellipse class="cls-4" cx="29.8" cy="8.12" rx="22.86" ry="4.76"/><line class="cls-3" x1="5.46" y1="14.46" x2="5.46" y2="41.93"/><line class="cls-3" x1="30.86" y1="18.98" x2="30.86" y2="46.45"/><line class="cls-3" x1="55.9" y1="12.89" x2="55.9" y2="40.36"/><line class="cls-3" x1="44.1" y1="17.66" x2="44.1" y2="45.13"/><line class="cls-3" x1="17.63" y1="17.66" x2="17.63" y2="45.13"/></svg>'
        ).translate!(0, 70)
  end
  
  def samplecolumn(opened: false, contents: 'empty')
    column =  SVGElement.new(boundx: 46.92, boundy: 132.74)
    if contents == 'empty' && !opened
      column.add_child(
        '<svg><defs><style>.cls-1_sc{fill:#fff;}.cls-1_sc,.cls-2_sc{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_sc{fill:none;}</style></defs><path class="cls-1_sc" d="M375.23,260.43V338c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37L412,260.41a2.52,2.52,0,0,0-2.52-2.5H377.75A2.52,2.52,0,0,0,375.23,260.43Z" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_sc" x="3.51" y="9.99" width="36.77" height="4.72" rx="1.19" ry="1.19"/><path class="cls-1_sc" d="M377.22,252.44v51.26a1.65,1.65,0,0,0,.85,1.44l5.56,3.06a1.65,1.65,0,0,1,.85,1.44v7.3a1.65,1.65,0,0,0,1.65,1.65h14.54a1.65,1.65,0,0,0,1.65-1.65v-7.25a1.65,1.65,0,0,1,.91-1.48l6.18-3.09a1.65,1.65,0,0,0,.91-1.48V252.44" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="14.16" y="70.95" width="15.06" height="6.09" rx="0.98" ry="0.98"/><rect class="cls-1_sc" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_sc" d="M416.1,248" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M411.38,248.51" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M412,250.08a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M412,251.91a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="1.05" y="17.78" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
        )
    elsif contents == 'no-collector' && closed
      column.add_child(
        '<svg><defs><style>.cls-1_sc{fill:#fff;}.cls-1_sc,.cls-2_sc{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_sc{fill:none;}</style></defs><rect class="cls-1_sc" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_sc" x="3.51" y="9.99" width="36.77" height="4.72" rx="1.19" ry="1.19"/><path class="cls-1_sc" d="M377.46,280.13v51.26a1.65,1.65,0,0,0,.85,1.44l5.56,3.06a1.65,1.65,0,0,1,.85,1.44v7.3a1.65,1.65,0,0,0,1.65,1.65h14.54a1.65,1.65,0,0,0,1.65-1.65v-7.25a1.65,1.65,0,0,1,.91-1.48l6.18-3.09a1.65,1.65,0,0,0,.91-1.48V280.13" transform="translate(-371.95 -265.42)"/><rect class="cls-1_sc" x="14.16" y="70.95" width="15.06" height="6.09" rx="0.98" ry="0.98"/><rect class="cls-1_sc" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_sc" d="M416.34,275.65" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M411.62,276.2" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M412.23,277.77a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M412.23,279.61a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.95 -265.42)"/></svg>'
        )
    else
      column.add_child(samplecolumn.translate!(0,-70)) #default to closed and empty if options could not be matched
    end
    column.translate!(0,70)
  end
  
  def collectiontube(contents: 'empty')
    ctube = SVGElement.new(boundx: 46.92, boundy: 132.74)
    if contents == 'empty'
      ctube.add_child(
        '<svg><defs><style>.cls-1_collection_tube{fill:none;stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}</style></defs><path class="cls-1_collection_tube" d="M377.69,251.62v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H380.21A2.52,2.52,0,0,0,377.69,251.62Z" transform="translate(-374.97 -246.46)"/><rect class="cls-1_collection_tube" x="0.25" y="0.25" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
        )
    elsif contents == 'full'
      ctube.add_child(
        '<svg><defs><style>.cls-1_collection_tube{fill:#26afe5;}.cls-2_collection_tube{fill:#fff;}.cls-2_collection_tube,.cls-3_collection_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3_collection_tube{fill:none;}</style></defs><path class="cls-1_collection_tube" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1_collection_tube" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2_collection_tube" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/></svg>'
        )
    end
  end
  
  def tube(opened: false, contents: 'empty')
    tube = SVGElement.new(boundx: 46.92, boundy: 132.74)
    
    if contents == 'empty' && !opened
      tube.add_child(
        '<svg><defs><style>.cls-1_tube{fill:#fff;}.cls-1_tube,.cls-2_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_tube{fill:none;}</style></defs><rect class="cls-1_tube" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_tube" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_tube" d="M411.36,243.86" transform="translate(-371.69 -233.08)"/><path class="cls-2_tube" d="M412,245.43a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.69 -233.08)"/><path class="cls-2_tube" d="M412,247.27a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.69 -233.08)"/><rect class="cls-1_tube" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/><path class="cls-2_tube" d="M374.62,249.27V304.5l11.32,68c.8,4.79,4.61,5.75,7.86,5.09s4.39-5.33,4.39-5.33l13.16-67.79V249.27Z" transform="translate(-371.69 -233.08)"/></svg>'
        )
    elsif contents == 'empty' && opened
      tube.add_child(
        '<svg><defs><style>.cls-1_tube{fill:none;}.cls-1_tube,.cls-2_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_tube{fill:#fff;}</style></defs><title>Untitled-1</title><path class="cls-1_tube" d="M410.51,263.07" transform="translate(-371.13 -215.85)"/><path class="cls-1_tube" d="M411.12,264.64a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.13 -215.85)"/><path class="cls-1_tube" d="M411.12,266.47a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.13 -215.85)"/><rect class="cls-2_tube" x="0.25" y="47.83" width="42.32" height="4.79" rx="2.4" ry="2.4"/><path class="cls-1_tube" d="M373.78,268.47V323.7l11.32,68c.8,4.79,4.61,5.75,7.86,5.09s4.39-5.33,4.39-5.33l13.16-67.79V268.47Z" transform="translate(-371.13 -215.85)"/><rect class="cls-2_tube" x="394.99" y="233.39" width="33.11" height="9.82" rx="2.36" ry="2.36" transform="translate(236.03 -411.02) rotate(84.22)"/><rect class="cls-2_tube" x="393.55" y="233.89" width="42.88" height="7.39" rx="2.36" ry="2.36" transform="translate(238.41 -415.09) rotate(84.22)"/></svg>'
        )
    end
    tube.translate!(0,70)
  end
  
  # svg_func: a symbol method name for a function that returns an SVGElement
  # svg_label: label for svg
  # opts: option hash to be applied to svg_func as named parameters
  #
  # example: svg = draw_svg(:tube, svg_label: "Hello\nWorld", opened: true, full: true)
  def draw_svg(svg_func, svg_label: nil, **opts)
    svg = method(svg_func).call(**opts)
    svg = label_object(svg, svg_label) if svg_label
    svg
  end
  
  def label_object(svg, _label)
    def label_helper(svg, labels, offsety = 0)
      l = label(labels.shift, "font-size".to_sym => 25)
      l.align!('center-center')
      l.translate!(svg.boundx / 2, svg.boundy / 2 + offsety.to_i)
      svg.add_child(l)
      return label_helper(svg, labels, offsety + 25) unless labels.empty?
      return svg
    end
    
    labels = _label.split("\n")
    return label_helper(svg, labels, 0)
  end
end
```
