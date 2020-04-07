# OLASimple PCR

New Documentation

### Inputs


- **Patient Sample** [P]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLASimple Synthetic DNA")'>OLASimple Synthetic DNA</a>



### Outputs


- **PCR Product** [P]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA PCR")'>OLA PCR</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
##########################################
#
#
# OLASimple PCR
# author: Justin Vrana
# date: March 2018
#
#
##########################################

needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics

  ##########################################
  # INPUT/OUTPUT
  ##########################################
  INPUT = "Patient Sample"
  OUTPUT = "PCR Product"
  PACK = "PCR Pack"
  A = "Diluent A"

  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################


  # TUBE LABELS ARE DIFF FOR NUTTADA
  # Nuttada: Introduction NO CELL LYSATE OR MENTION BLOOD (USE NONINFECTION SYNTHETIC DNA)
  # use only P200 pipette
  # change to P20 pipette
  # eliminate 10% bleach / 70% ethanol
  # eliminate timer from materials list
  # NUTTADA: R1 fridge, name pre-pcr bench
  # "Tear open package. There are two section. Tear open both "
  # throw error if two operations have same input item
  # change transfer images to P200
  # centrifuge sample after vortexing (after pcr rehydration)
  # Nuttada: cell lysate > DNA sample

  # Manually put in pack hash...
  PACK_HASH = {
      "Unit Name" => "B",
      "Components" => {
          "sample tube" => "A",
          "diluent A" => "B"
      },
      "PCR Rehydration Volume" => 40,
      "Number of Samples" => 2,
      "Number of Sub Packages" => 2,
  }

  AREA = PRE_PCR
  SAMPLE_VOLUME = 10 # volume of sample to add to PCR mix
  PCR_MIX_VOLUME = PACK_HASH["PCR Rehydration Volume"] # volume of water to rehydrate PCR mix in
  CENTRIFUGE_TIME = "5 seconds" # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = "5 seconds" # time to pulse vortex to mix

  # for debugging
  PREV_COMPONENT = "K"
  PREV_UNIT = "A"


  TUBE_CAP_WARNING = "Check to make sure tube caps are completely closed."

  component_to_name_hash = {
      "diluent A" => "Diluent A",
      "sample tube" => "PCR sample"
  }

  MATERIALS = [
      "P200 pipette and filtered tips",
      "P20 pipette and filtered tips",
      "a timer",
      "nitrile gloves (wear tight gloves to reduce contamination risk)",
      "pre-PCR rack",
      "a balancing tube (on rack)",
      "biohazard waste (red bag)",
      "vortex",
      "centrifuge",
  ]
  
  
  SAMPLE_ALIAS = if KIT_NAME == "uw kit" then "DNA Sample" else CELL_LYSATE end

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################


  def main


    operations.running.retrieve interactive: false
    save_user operations
    debug_setup(operations) if debug
    
    if KIT_NAME == "uw kit"
        if debug
            labels = "ABCDEF".split('')
            operations.each.with_index do |op, i|
                op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])  
                op.input(INPUT).item.associate(COMPONENT_KEY, "")  
            end
        end
    end
    
    save_temporary_input_values(operations, INPUT)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)
    
    # reassign labels to sample numbers if uw kit
    if KIT_NAME == "uw kit"
        operations.each do |op|
            op.temporary[:output_sample] = {"A"=>1, "B"=>2}[op.temporary[:output_sample]]
        end 
    end
    
    run_checks operations
    if KIT_NAME == "uw kit"
        uw_kit_introduction operations.running
    else
        kenya_kit_introduction operations.running
    end
    area_preparation "pre-PCR", MATERIALS, POST_PCR
    get_pcr_packages operations.running
    open_pcr_packages operations.running
    debug_table operations.running
    check_for_tube_defects sorted_ops.running
    # nuttada thaw
    # nuttada needs vortex + centrigure
    centrifuge_samples sorted_ops.running
    resuspend_pcr_mix sorted_ops.running
    add_template_to_master_mix sorted_ops.running
    cleanup sorted_ops
    start_thermocycler sorted_ops.running
    conclusion sorted_ops
    return {}
  end # main

  # end of main


  #######################################
  # Utilities
  #######################################
  def save_user ops
    ops.each do |op|
      username = get_technician_name(self.jid)
      op.associate(:technician, username)
    end
  end

  def debug_setup ops
    # make an alias for the inputs
    if debug
      ops.each do |op|
        kit_num = rand(1..60)
        make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENT, 1)
        # op.input(PACK).item.associate(KIT_KEY, kit_num)
      end

      if ops.length >= 2
        i = ops[-1].input(INPUT).item
        alias_array = get_alias_array(i)
        alias_array[3] = if (alias_array[3] == 1) then
                           2
                         else
                           1
                         end
        make_alias(ops[0].input(INPUT).item, *alias_array)

        # kit_num = ops[-1].input(PACK).item.get(KIT_KEY)
        # ops[0].input(PACK).item.associate(KIT_KEY, kit_num)
      end
    end
  end

  def run_checks myops
    if operations.running.empty?
      show do
        title "All operations have errored"
        note "Contact #{SUPERVISOR}"
        operations.each do |op|
          note "#{op.errors.map {|k, v| [k, v]}}"
        end
      end
      return {}
    end
  end

  def sorted_ops
    operations.sort_by {|op| op.output_ref(OUTPUT)}.extend(OperationList)
  end

  #######################################
  # Instructions
  #######################################
 
  def uw_kit_introduction ops
    username = get_technician_name(self.jid).color("darkblue")
    kit_nums = ops.map {|op| op.input(INPUT).item.get(KIT_KEY)}.uniq
    samples = "#{ops.length} #{"sample".pluralize(ops.length)}"
    kits = "#{kit_nums.length} #{"kit".pluralize(kit_nums.length)}"
    show do
      title "Welcome #{username} to OLASimple PCR"
      note "You will be running the OLASimple PCR protocol. In this protocol, you will start with non-infectious, synthetic DNA. " \
           "You will generate PCR products from the samples and use them later to detect HIV mutations."
     check "OLASimple PCR assay is highly sensitive. If the space is not clean, this could cause false positive. Before proceeding this step, check with your assigner if the space and pipettes have been wiped with 10% bleach and 70% ethanol"
      note "You will be running #{samples} from #{kits}."
      note "Click <b>OK</b> in the upper right corner to start the protocol."
    end
  end
  
  def kenya_introduction ops
    username = get_technician_name(self.jid).color("darkblue")
    kit_nums = ops.map {|op| op.input(INPUT).item.get(KIT_KEY)}.uniq
    samples = "#{ops.length} #{"sample".pluralize(ops.length)}"
    kits = "#{kit_nums.length} #{"kit".pluralize(kit_nums.length)}"
    show do
      title "Welcome #{username} to OLASimple PCR"
      note "You will be running the OLASimple PCR protocol. In this protocol, you will start with #{CELL_LYSATE}. " \
           "You will generate PCR products from the samples and use them later to detect HIV mutations."
      note "You will be running #{samples} from #{kits}."
      note "Click <b>OK</b> in the upper right corner to start the protocol."
    end
  end

  def get_pcr_packages myops
    # TODO: remove all references to 4C fridge and replace with refridgerator
    gops = group_packages(myops)
    show do
      title "Take #{PCR_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE} R1 and place on the #{BENCH} in the #{AREA}"
      # check "Take the following from the #{FRIDGE} and place #{pluralizer(PACKAGE, gops.length)} on the #{BENCH}"
      gops.each do |unit, ops|
        check "Take " "#{PACKAGE} #{unit.bold}" " from R1 fridge."
        check "Place " "#{PACKAGE} #{unit.bold}" " on the bench." 
        check "Put on a new pair of gloves. R1 fridge is located in the post-PCR area so your gloves might have picked up some DNA that could contaminate your assay."
      end
    end
  end

  def open_pcr_packages myops
    grouped_by_unit = myops.group_by {|op| op.temporary[:output_kit_and_unit]}
    grouped_by_unit.each do |kit_and_unit, ops|
      ops.each do |op|
        op.make_item_and_alias(OUTPUT, "sample tube", INPUT)
      end



      show_open_package(kit_and_unit, "", ops.first.temporary[:pack_hash][NUM_SUB_PACKAGES_FIELD_VALUE]) do
          # img
          tube_labels = ops.map {|op| op.output_ref(OUTPUT)}
          tube_labels += ops.map {|op| op.ref("diluent A")}
          tube_labels.uniq.sort!
    
          num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
          kit, unit, component, sample = ops.first.output_tokens(OUTPUT)
          # diluentATube = label_tube(closedtube, tube_label(kit, unit, diluentAcomponent, ""))
          diluentATube = self.make_tube(closedtube, "Diluent A", ops.first.tube_label("diluent A"), "medium", true)
    
          grid = SVGGrid.new(num_samples, 1, 75, 10)
          num_samples.times.each do |i|
            pcrtube = self.make_tube(closedtube, "", ["#{kit}#{unit}", "#{component}#{i + 1}"], "powder", true).scale(0.75)
            grid.add(pcrtube, i, 0)
          end
          grid.boundy = closedtube.boundy * 0.75
          grid.align_with(diluentATube, 'center-right')
          grid.align!('center-left')
          grid.translate!(25, 25)
          img = SVGElement.new(children: [diluentATube, grid], boundy: diluentATube.boundy + 50, boundx: 300).translate!(20)
        
        check "Look for #{num_samples + 1} #{"tube".pluralize(num_samples)}" # labeled #{tube_labels.join(', ').bold}"
        check "Place tubes on a rack"
        note display_svg(img, 0.75)
      end
    end
  end

  def debug_table myops
    if debug
      show do
        title "DEBUG: I/O Table"

        table myops.running.start_table
                  .custom_column(heading: "Input Kit") {|op| op.temporary[:input_kit]}
                  .custom_column(heading: "Output Kit") {|op| op.temporary[:output_kit]}
                  .custom_column(heading: "Input Unit") {|op| op.temporary[:input_unit]}
                  .custom_column(heading: "Output Unit") {|op| op.temporary[:output_unit]}
                  .custom_column(heading: "Diluent A") {|op| op.ref("diluent A")}
                  .custom_column(heading: "Input Ref") {|op| op.input_ref(INPUT)}
                  .custom_column(heading: "Output Ref") {|op| op.output_ref(OUTPUT)}
                  .end_table
      end
    end
  end

  def centrifuge_samples ops
    labels = ops.map {|op| ref(op.output(OUTPUT).item)}
    diluentALabels = ops.map {|op| op.ref("diluent A")}
    show do
        title "Obtain samples from your assigner."
        check "Do the samples match your kit number?"
        check "Vortex sample tubes for 5 seconds."
    end
    show do
        title "Centrifuge all samples for 5 seconds" 
        check "Place diluent A (BB), balancing tube, PCR dried reagents (BA1, BA2), and DNA samples (AA and AB) in the centrifuge. It is important to balance all the tubes."
        image "Actions/OLA/centrifuge.svg"
        check "Centrifuge the tubes for 5 seconds to pull down liquid and dried reagents"
    end
    # centrifuge_helper("sample", labels, CENTRIFUGE_TIME,
    #                   "to pull down dried powder.",
    #                   "There may be dried powder on the inside of the tube #{"lid".pluralize(labels.length)}.")
    # centrifuge_helper("tube", diluentALabels, CENTRIFUGE_TIME,
    #                   "to pull down liquid.")
  end

  def resuspend_pcr_mix myops
    gops = group_packages(myops)
    gops.each do |unit, ops|
      from = ops.first.ref("diluent A")
      ops.each do |op|
        to_item = op.output(OUTPUT).item
        to = ref(to_item)
        tubeA = make_tube(opentube, [DILUENT_A, from], "", fluid = "medium")
        tubeP = make_tube(opentube, [PCR_SAMPLE, to], "", fluid = "powder").scale!(0.75)
        img = make_transfer(tubeA, tubeP, 250, "#{PCR_MIX_VOLUME}uL", "(#{P200} pipette)")
        img.translate!(25)
        show do
          raw transfer_title_proc(PCR_MIX_VOLUME, from, to)
          # title "Add #{PCR_MIX_VOLUME}uL from #{DILUENT_A} #{from.bold} to #{PCR_SAMPLE} #{to.bold}"
          note "#{DILUENT_A} will be used to dissolve the powder in the #{PCR_SAMPLE}."
          note "Use a #{P200} pipette and set it to [0 4 0]."
          note "Avoid touching the inside of the lid, as this could cause contamination. "
          note "Dispose of pipette tip."
          note display_svg(img, 0.75)
        end
      end

      # TODO: add "make sure tube caps are completely closed" for any centrifugation or vortexing step.
      #
    end

    labels = myops.map {|op| ref(op.output(OUTPUT).item)}
    vortex_and_centrifuge_helper("sample",
                                 labels,
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 "to mix.", "to pull down liquid", mynote = nil)

  end

  def add_template_to_master_mix myops
    gops = group_packages(myops)

    # # TODO: Should this be moved to the preparation area?
    # show do
    #   title "Place #{SAMPLE_ALIAS.bold} samples in #{AREA.bold}."
    #
    #   note "Place the following #{SAMPLE_ALIAS.bold} samples into a rack in the #{AREA.bold}."
    #   t = Table.new
    #   t.add_column("Tube", myops.map {|op| ref(op.input(INPUT).item)})
    #   table t
    #   # check "Wipe with a #{WIPE}"
    # end

    gops.each do |unit, ops|
      samples = ops.map {|op| op.input(INPUT).item}
      sample_refs = samples.map {|sample| ref(sample)}
      ops.each do |op|
        from = ref(op.input(INPUT).item)
        to = ref(op.output(OUTPUT).item)
        show do
          raw transfer_title_proc(SAMPLE_VOLUME, "#{SAMPLE_ALIAS} #{from}", "#{PCR_SAMPLE} #{to}")
          warning "<h1>Labels look very similar. Read the label three times before proceeding.<h1\>"
          note "Carefully open tube #{from.bold} and tube #{to.bold}"
          note "Use a #{P20} pipette and set it to [1 0 0]."
          warning "Close both tubes and dispose of pipette tip."
          tubeS = make_tube(opentube, [SAMPLE_ALIAS, from], "", fluid = "medium")
          tubeP = make_tube(opentube, [PCR_SAMPLE, to], "", fluid = "medium").scale!(0.75)
          img = make_transfer(tubeS, tubeP, 250, "#{SAMPLE_VOLUME}uL", "(#{P20} pipette)")
          img.translate!(25)
          note display_svg(img, 0.75)

        end

        # show do
        #   title "Mix and vortex #{PCR_SAMPLE} #{to.bold}"

        #   warning TUBE_CAP_WARNING
        #   check "Vortex #{pluralizer("sample", 1)} for #{VORTEX_TIME} to mix."
        #   check "Centrifuge #{pluralizer("sample", ops.length)} for #{CENTRIFUGE_TIME} to pull down liquid."
        # end
      end
    end
  end

  def start_thermocycler ops
    # Adds the PCR tubes to the PCR machine.
    # Instructions for PCR cycles.
    #
    samples = ops.map {|op| op.output(OUTPUT).item}
    sample_refs = samples.map {|sample| ref(sample)}

    # show do
    #   title "Bring #{pluralizer(PCR_SAMPLE, ops.length)} to the #{POST_PCR.bold} area"
    #   check "Walk #{"tube".pluralize(ops.length)} #{ops.map {|op| ref(op.output(OUTPUT).item).bold}.join(', ')} to the #{POST_PCR.bold} area"
    #   image "Actions/OLA/map_Klavins.svg" if KIT_NAME == "uw kit"
    # end

    # END OF PRE_PCR PROTOCOL

    vortex_and_centrifuge_helper(PCR_SAMPLE,
                                 ops.map {|op| ref(op.output(OUTPUT).item)},
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 "to mix.", "to pull down liquid", mynote = nil)


    # show do
    #   title "Place #{PCR_SAMPLE.pluralize(ops.length)} in #{THERMOCYCLER}, close and tighten the lid."
    # end

    t = Table.new()
    cycles_temp = "<table style=\"width:100%\">
                    <tr><td>95C</td></tr>
                    <tr><td>57C</td></tr>
                    <tr><td>72C</td></tr>
      </table>"
    cycles_time = "<table style=\"width:100%\">
                    <tr><td>30 sec</td></tr>
                    <tr><td>30 sec</td></tr>
                    <tr><td>30 sec</td></tr>
      </table>"
    t.add_column("STEP", ["Initial Melt", "45 cycles of", "Extension", "Hold"])
    t.add_column("TEMP", ["95C", cycles_temp, "72C", "4C"])
    t.add_column("TIME", ["4 min", cycles_time, "7 min", "forever"])
    
    
    show do
        title "Run PCR"
        check "Talk to your assigner which thermocycler to use"
        check "Close all the lids of the pipette tip boxes and pre-PCR rack"
        check "Take only the PCR tubes (BA1 and BA2) with you"
        check "Place the PCR samples in the assigned thermocycler, close, and tighten the lid"
        check "Select the program named #{PCR_CYCLE} under OS"
        check "Hit #{"Run".quote} and #{"OK to 50uL".quote}"
        table t
    end
    
    operations.each do |op|
      op.output(OUTPUT).item.move THERMOCYCLER
    end

    # END OF POST_PCR PCR REACTION...
  end

  def cleanup myops

    items = [INPUT].map {|x| myops.map {|op| op.input(x)}}.flatten.uniq
    item_refs = [INPUT].map {|x| myops.map {|op| op.input_ref(x)}}.flatten.uniq
    # if KIT_NAME == "uw kit"
    #     item_refs = [] 
    # end
    temp_items = ["diluent A"].map {|x| myops.map {|op| op.ref(x)}}.flatten.uniq

    all_refs = temp_items + item_refs

    show do
      title "Throw items into the #{WASTE}"

      note "Throw the following items into the #{WASTE} in the #{AREA} area"
      t = Table.new
      t.add_column("Tube".bold, all_refs)
      table t
    end
    # clean_area AREA
  end

  def conclusion myops
    # if KIT_NAME == "uw kit"
    #     show do 
    #         title "Please return DNA tubes"
    #         check "Please return tubes #{myops.map { |op| op.input_ref(INPUT).bold}.join(', ')} to the <b>M20 \"BOX 1A-60D\"</b>"
    #         image "Actions/OLA/map_Klavins.svg "
    #     end
    # end
    show do
      title "Thank you!"
      warning "<h2>You must click #{"OK".quote.bold} to complete the protocol</h2>"
      check " After clicking #{"OK".quote.bold}, discard your gloves and wash your hands with soap. "
      note "You may start the next protocol in 2 hours."
    end
  end


end # Class
```
