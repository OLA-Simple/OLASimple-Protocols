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

  INCOMING_SAMPLE_PREFIX = "S"

  DTT = PACK_HASH["Components"]["DTT/tRNA"]
  LYSIS_BUFFER = PACK_HASH["Components"]["Lysis buffer"]
  WASH1 = PACK_HASH["Components"]["Wash 1"]
  WASH2 = PACK_HASH["Components"]["Wash 2"]
  SA_WATER= PACK_HASH["Components"]["sodium azide water"]
  SAMPLE_COLUMN = PACK_HASH["Components"]["Sample column"]
  RNA_EXTRACT = PACK_HASH["Components"]["Extract tube"]
  
  GuSCN_WASTE = "Discard flow into GuSCN waste container"
  
  SHARED_COMPONENTS = [DTT, WASH1, WASH2, SA_WATER]
  PER_SAMPLE_COMPONENTS = [LYSIS_BUFFER, SAMPLE_COLUMN, RNA_EXTRACT]

  THIS_UNIT = PACK_HASH["Unit Name"]
  NUM_SAMPLES = PACK_HASH["Number of Samples"]

  CENTRIFUGE_TIME = "1 minute"
  CENTRIFUGE_EXTRA_INSTRUCTIONS = "Discard flow through in GuSCN waste container"

  def main

    this_package = prepare_protocol_operations

    kit_svgs = make_kit_svgs

    introduction
    safety_warning
    required_equipment
    
    retrieve_inputs
    kit_num = extract_kit_number(this_package)
    sample_validation_with_multiple_tries(kit_num)
    
    retrieve_and_open_package(this_package, kit_svgs)
    
    prepare_buffers
    lyse_samples
    add_ethanol

    3.times do
      operations.each { |op| add_sample_to_column(op) }
      centrifuge_columns(GuSCN_WASTE)
    end
    change_collection_tubes

    add_buffer_e2
    centrifuge_columns(GuSCN_WASTE)
    change_collection_tubes
    
    add_buffer_e3
    centrifuge_columns(GuSCN_WASTE)
    change_collection_tubes

    transfer_column_to_e6
    elute
    incubate(sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }, "1 minute")
    centrifuge_columns("<b>DO NOT DISCARD FLOW</b>")

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
    if operations.length > 2
      raise "Batch size > 2 is not supported for this protocol. Please rebatch."
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


  def make_kit_svgs
    base_svg_representations = {
        DTT => roundedtube,
        LYSIS_BUFFER => roundedtube,
        SA_WATER => roundedtube,
        WASH1 => screwbottle,
        WASH2 => screwbottle,
        SAMPLE_COLUMN => samplecolumn,
        RNA_EXTRACT => closedtube,
    }
    
    
    svgs = {}
    operations.each do |op|
      sample_num = op.temporary[:input_sample]
      PER_SAMPLE_COMPONENTS.each_with_index do |component|
        svg = label_object(
                SVGElement.load(base_svg_representations[component].dump),
                "#{component}\n#{sample_num}"
              )
        svgs["#{component}-#{sample_num}"] = svg
      end
    end
    
    SHARED_COMPONENTS.each do |component|
      svg = label_object(base_svg_representations[component], component)
      svgs[component] = svg
    end
    svgs
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

      note "In this protocol you will lyse the virus and purify RNA from HIV-infected plasma.. "
      check "OLA RNA Extraction is sensitive to contamination. Small contamination from the previously amplified products can cause false positive. Before proceed, wipe the space and pipettes with 10% bleach (freshly prepared or prepared daily) and 70% ethanol."
      check "Put on tight gloves. Tight gloves help reduce chances for your gloves to be trapped when closing the tubes which can increase contamination risk."
      note "RNA is prone to degradation by RNase present in our eyes, skin, and breath. Avoid opening tubes outside the BSC."
      note "Change gloves after touching the common surface (such as refrigerator door handle) as your gloves now can be contaminated by RNase or other previously amplified products that can cause false positives."
      check "Before starting this protocol, make sure you have access to molecular grade ethanol (~10 mL). Do not use other grades of ethanol as this will negatively affect the RNA extraction yield."

    end

  end

  def safety_warning
    show do
      title "Review the safety warnings"
      warning "You will be working with infectious materials."
      note "Do <b>ALL</b> work in a biosafety cabinet (#{BSC.bold})"
      note "Always wear a lab coat and gloves for this protocol."
      warning "Do not mix #{LYSIS_BUFFER} or #{WASH1} with bleach, as this will generate toxic cyanide gas. #{LYSIS_BUFFER} AND #{WASH1} waste must be discarded appropriately based on guideline for GuSCN handling waste"
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
  
  def retrieve_and_open_package(this_package, kit_svgs)
    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{BSC}"
      check "Grab package"
      check "Remove the <b>outside layer</b> of gloves (since you just touch the door knob)."
      check "Put on new outside layer gloves."
    end
    
    # show_open_package(this_package, "", 0) do
    #   tube = make_tube(closedtube, "", operations.first.tube_label("diluent A"), "medium")
    #   num_samples = operations.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
    #   grid = SVGGrid.new(1, num_samples, 0, 100)
    #   tokens = operations.first.output_tokens(OUTPUT)
    #   num_samples.times.each do |i|
    #     _tokens = tokens.dup
    #     _tokens[-1] = i+1
    #     ligation_tubes = display_ligation_tubes(*_tokens, COLORS)
    #     stripwell = ligation_tubes.g
    #     grid.add(stripwell, 0, i)
    #   end
    #   grid.align_with(tube, 'center-right')
    #   grid.align!('center-left')
    #   img = SVGElement.new(children: [tube, grid], boundx: 1000, boundy: 300).translate!(30, -50)
    #   note "Check that the following tubes are in the pack:"
    #   note display_svg(img, 0.75)
    # end
    show_open_package(this_package, "", 0) do
      img = kit_image(kit_svgs)
      check "Check that the following tubes are in the pack:"
      note display_svg(img, 0.75)
      note "Arrange tubes on plastic rack for later use."
    end
  end
  
  def kit_image(kit_svgs)
    grid = SVGGrid.new(PER_SAMPLE_COMPONENTS.size + SHARED_COMPONENTS.size, operations.size, 80, 100)

    SHARED_COMPONENTS.each_with_index do |component, i|
      svg = kit_svgs[component]
      grid.add(svg, i, 0)
    end

    operations.each_with_index do |op, i|
      sample_num = op.temporary[:input_sample]
      PER_SAMPLE_COMPONENTS.each_with_index do |component, j|
        svg = kit_svgs["#{component}-#{sample_num}"]
        grid.add(svg, j + SHARED_COMPONENTS.size, i)
      end
    end
    grid.align!('center-left')
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate!(30, 50)
  end
  
  
  def retrieve_inputs
    input_samples = sample_labels.map {  |s| "#{INCOMING_SAMPLE_PREFIX}-#{s}" }
    show do
      title "Retrieve Samples"
      check "Take #{input_samples.to_sentence} from #{FRIDGE_PRE}"
    end
  end
  
  # helper method for simple transfers in this protocol
  def transfer_and_vortex(title, from, to, volume, warning = nil)
    show do
      title title
      check "Transfer <b>#{volume}</b> of <b>#{from}</b> into <b>#{to}</b>."
      warning warning if warning
      check 'Discard pipette tip.'
      check "Vortex <b>#{to}</b> for <b>2 seconds, twice</b>."
      check "Centrifuge <b>#{to}</b> for <b>5 seconds</b>."
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

  def centrifuge_columns(flow_instructions)
    columns = sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}"}
    
    show do
      title " Centrifuge Columns for #{CENTRIFUGE_TIME}"
      warning "Ensure both tube caps are closed"
      raw centrifuge_proc("Column", columns, CENTRIFUGE_TIME, "", AREA)
      check flow_instructions
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
        '10uL'
      )
    end    

    # prepare wash buffer 2 with ethanaol
    transfer_and_vortex(
      "Prepare #{WASH2}", 
      ETHANOL, 
      WASH2, 
      '1600uL',
      'Do not use other grades of ethanol.'
    )
  end
  
  SAMPLE_VOLUME = "300ul"
  # transfer plasma Samples into lysis buffer and incubate
  def lyse_samples
    operations.each do |op|
      transfer_and_vortex(
        'Lyse Samples', 
        "#{INCOMING_SAMPLE_PREFIX}-#{op.temporary[:input_sample]}",
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        '300uL'
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
        '1200uL'
      )
    end
  end

  def add_sample_to_column(op)
    show do
      title 'Add Sample to Column'
      check "<b>Carefully</b> open lid of <b>#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}</b>"
      check "Carefully apply <b>800uL</b> of <b>#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}</b> onto the column <b>#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}</b>"
      check "<b>Slowly</b> close lid of <b>#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}</b>"
    end
  end

  def change_collection_tubes
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do
      title 'Change Collection Tubes'
      sample_columns.each do |column|
        check "Transfer <b>#{column}</b> to new collection tube."
      end
      note "Discard previous collection tubes."
    end
  end

  def add_buffer_e2
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do 
      title "Add Buffer #{WASH1}"
      sample_columns.each do |column|
        note "<b>Carefully</b> open column <b>#{column}</b> lid."
        check "<b>Carefully</b> Add <b>500uL</b> of buffer <b>#{WASH1}</b> to <b>#{column}</b>, and close the lid."
        check 'Discard pipette tip.'
        note "<b>Slowly</b> close lid of <b>#{column}</b>"
      end
    end
  end

  def add_buffer_e3
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do 
      title "Add Buffer #{WASH2}"
      sample_columns.each do |column|
        note "<b>Carefully</b> open column <b>#{column}</b> lid."
        check "<b>Carefully</b> Add <b>500uL</b> of buffer <b>#{WASH2}</b> to <b>#{column}</b>, and close the lid."
        check 'Discard pipette tip.'
        note "<b>Slowly</b> close lid of <b>#{column}</b>"
      end
    end
  end

  def transfer_column_to_e6
    show do
      title 'Transfer Columns'
      warning "Make sure the bottom of the E5 and E6 columns are not touching any fluid from the collection tubes. When in doubt, centrifuge for 1 more minute"
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
      check 'Spray and wipe down all reagents and sample tubes with bleach and ethanol.'
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
      note "Spray down surface of BSC with 10% bleach. Wipe clean using paper towel."
      note "Spray down surface of BSC with 70% ethanol. Wipe clean using paper towel."
      note "After cleaning, dispose of gloves and paper towels in #{WASTE_PRE}."
    end
  end

  def store
    show do
      title 'Store Items'
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}"}
      note "Store <b>#{extract_tubes.to_sentence}</b> in the fridge on the cold rack in fridge if the amplification module will be proceeded immediately."
      
      note "Store <b>#{extract_tubes.to_sentence}</b> in -20C freezer if proceeding with the amplification module later."
    end
  end
  
  ####################################################################################
  #### SVGs                                                                       ####
  ####################################################################################
  def roundedtube()
    _roundedtube = SVGElement.new(boundx: 46.92, boundy: 132.74)
    _roundedtube.add_child(
        '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2{fill:#fff;}.cls-2,.cls-3{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3{fill:none;}</style></defs><title>Untitled-18</title><path class="cls-1" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-2" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-3" d="M412.06,252" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,253.6a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,255.44a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M375.39,257.57v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H377.91A2.52,2.52,0,0,0,375.39,257.57Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
        ).translate!(0,70)
  end
  
  def screwbottle
    _screwbottle = SVGElement.new(boundx: 46.92, boundy: 132.74)
    _screwbottle.add_child(
        '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2,.cls-3{fill:none;}.cls-3,.cls-4{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-4{fill:#fff;}</style></defs><path class="cls-1" d="M377.92,325.7c-4.23-1-8.46.27-11.89,2v31.86a8.73,8.73,0,0,0,8.71,8.71h41.68a8.73,8.73,0,0,0,8.71-8.71V328.25c-9.24.24-7.87,3.46-19.44,7.63S387.64,328,377.92,325.7Z" transform="translate(-365.78 -243.8)"/><path class="cls-2" d="M369,280.29" transform="translate(-365.78 -243.8)"/><rect class="cls-3" x="0.25" y="43.66" width="59.09" height="80.08" rx="8.6" ry="8.6"/><path class="cls-4" d="M395.58,244c-16.32,0-29.55,3.59-29.55,8V285.6c0,4.42,13.23,8,29.55,8s29.55-3.59,29.55-8V252.05C425.12,247.63,411.89,244,395.58,244Z" transform="translate(-365.78 -243.8)"/><ellipse class="cls-4" cx="29.8" cy="8.12" rx="22.86" ry="4.76"/><line class="cls-3" x1="5.46" y1="14.46" x2="5.46" y2="41.93"/><line class="cls-3" x1="30.86" y1="18.98" x2="30.86" y2="46.45"/><line class="cls-3" x1="55.9" y1="12.89" x2="55.9" y2="40.36"/><line class="cls-3" x1="44.1" y1="17.66" x2="44.1" y2="45.13"/><line class="cls-3" x1="17.63" y1="17.66" x2="17.63" y2="45.13"/></svg>'
        ).translate!(0, 70)
  end
  
  def samplecolumn
    column =  SVGElement.new(boundx: 46.92, boundy: 132.74)
    column.add_child(
      '<svg><defs><style>.cls-1{fill:#fff;}.cls-1,.cls-2{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2{fill:none;}</style></defs><path class="cls-1" d="M375.23,260.43V338c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37L412,260.41a2.52,2.52,0,0,0-2.52-2.5H377.75A2.52,2.52,0,0,0,375.23,260.43Z" transform="translate(-371.72 -237.72)"/><rect class="cls-1" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1" x="3.51" y="9.99" width="36.77" height="4.72" rx="1.19" ry="1.19"/><path class="cls-1" d="M377.22,252.44v51.26a1.65,1.65,0,0,0,.85,1.44l5.56,3.06a1.65,1.65,0,0,1,.85,1.44v7.3a1.65,1.65,0,0,0,1.65,1.65h14.54a1.65,1.65,0,0,0,1.65-1.65v-7.25a1.65,1.65,0,0,1,.91-1.48l6.18-3.09a1.65,1.65,0,0,0,.91-1.48V252.44" transform="translate(-371.72 -237.72)"/><rect class="cls-1" x="14.16" y="70.95" width="15.06" height="6.09" rx="0.98" ry="0.98"/><rect class="cls-1" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2" d="M416.1,248" transform="translate(-371.72 -237.72)"/><path class="cls-2" d="M411.38,248.51" transform="translate(-371.72 -237.72)"/><path class="cls-2" d="M412,250.08a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.72 -237.72)"/><path class="cls-2" d="M412,251.91a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.72 -237.72)"/><rect class="cls-1" x="1.05" y="17.78" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
      ).translate!(0,70)
  end
  
  def label_object(svg, _label, offsety = nil)
    def label_helper(svg, labels, offsety)
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
