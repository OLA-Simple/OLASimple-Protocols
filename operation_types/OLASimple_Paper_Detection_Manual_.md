# OLASimple Paper Detection (Manual)

Samples from the OLASimple ligation protocol are added onto paper detection strips. Then, an an image of the strips is scanned and uploaded. The strips will detect whether the sample has drug resistance mutations. In the next protocol, a visual call will be made determining the results of the strips.
### Inputs


- **Ligation Product** [LP]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Ligation Stripwell")'>OLA Ligation Stripwell</a>



### Outputs


- **Detection Strip** [LP]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Detection Strips")'>OLA Detection Strips</a>

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
##########################################
#
#
# OLASimple Detection
# author: Justin Vrana
# date: March 2018
#
#
##########################################

needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics

#   ##########################################
#   # INPUT/OUTPUT
#   ##########################################
#   F
  INPUT = "Ligation Product"
  OUTPUT = "Detection Strip"
  PACK = "Detection Pack"
  A = "Diluent A"
  G = "Gold Mix"
  S = "Stop Mix"

#   ##########################################
#   # TERMINOLOGY
#   ##########################################

#   ##########################################
#   # Protocol Specifics
#   ##########################################
  AREA = POST_PCR
  NUM_SUB_PACKAGES = 4

#   # 6 codons,
#   # GOLD_VOLUME = 600
#   # STOP_VOLUME = 36
#   # STOP_TO_SAMPLE_VOLUME = 2.4
#   # SAMPLE_TO_STRIP_VOLUME = 24
#   # GOLD_TO_STRIP_VOLUME = 40

#   # VOLUMES WILL CHANGES FOR 6 codons!!!!
  CENTRIFUGE_TIME = "5 seconds" # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = "5 seconds" # time to pulse vortex to mix
  TUBE_CAP_WARNING = "Check to make sure tube caps are completely closed."
  PACK_HASH = DETECTION_UNIT
  STOP_VOLUME = PACK_HASH["Stop Rehydration Volume"]
  GOLD_VOLUME = PACK_HASH["Gold Rehydration Volume"]
  STOP_TO_SAMPLE_VOLUME = PACK_HASH["Stop to Sample Volume"]  # volume of competitive oligos to add to sample
  SAMPLE_TO_STRIP_VOLUME = PACK_HASH["Sample to Strip Volume"] # volume of sample to add to the strips
  GOLD_TO_STRIP_VOLUME = PACK_HASH["Gold to Strip Volume"]
  PREV_COMPONENTS = PACK_HASH["Components"]["strips"]
  PREV_UNIT = "C"
  MATERIALS =  [
      "P1000 pipette and filtered tips",
      "P200 pipette and filtered tips",
      "P20 pipette and filtered tips",
      "a spray bottle of 10% v/v bleach",
      "a spray bottle of 70% v/v ethanol",
      "a timer",
      "nitrile gloves"
  ]


##########################################
# ##
# Input Restrictions:
# Input needs a kit, unit, components,
# and sample data associations to work properly
##########################################

  def main
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_user operations
    operations.running.retrieve interactive: false
    debug_setup operations
    save_temporary_input_values(operations, INPUT)
    save_temporary_output_values(operations)
    introduction operations.running
    area_preparation POST_PCR, MATERIALS, PRE_PCR
    get_detection_packages operations.running
    open_detection_packages operations.running
    rehydrate_stop_solution sorted_ops.running
    wait_for_pcr sorted_ops.running
    stop_ligation_product sorted_ops.running
    # short_timer
    rehydrate_gold_solution sorted_ops.running
    display_detection_strip_diagram
    add_ligation_product_to_strips sorted_ops.running
    add_gold_solution sorted_ops.running
    read_from_scanner sorted_ops.running
    # if KIT_NAME == "uw kit"
    #     run_image_analysis operations.running 
    # end
    cleanup sorted_ops
    conclusion sorted_ops
    return {"Ok" => 1}
  end

  def sorted_ops
    operations.sort_by {|op| op.output_ref(OUTPUT)}.extend(OperationList)
  end

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
        INPUT
        PREV_UNIT
        PREV_COMPONENTS
        make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENTS, 1)
        # op.input(PACK).item.associate(KIT_KEY, kit_num)
      end

      if ops.length >= 2
        i = ops[-1].input(INPUT).item
        alias_array = get_alias_array(i)
        alias_array[3] = if (alias_array[3] == 1) then 2 else 1 end
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

  def introduction myops
    username = get_technician_name(self.jid).color("darkblue")
    show do
      title "Welcome #{username} to OLASimple Paper Detection procotol"
      note "In this protocol you will be adding samples from the ligation protocol onto paper detection strips. " \
            "You will then scan an image of the strips and upload the image. The strips will detect whether the sample has drug resistance mutations."
      check "Put on gloves."      
      note "Click \"OK\" to start the protocol."
    end
  end

  def get_detection_packages(myops)
    gops = group_packages(myops)
    show do
      title "Get #{DET_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_POST}"
      gops.each do |unit, ops|
        check "package #{unit.bold}"
      end
      check "Place #{pluralizer('package', gops.length)} on the bench in the #{AREA.bold} area."
    end
  end

  def open_detection_packages(myops)
    grouped_by_unit = myops.running.group_by {|op| op.temporary[:output_kit_and_unit]}
    grouped_by_unit.each do |unit, ops|
      ops.each do |op|
        op.make_collection_and_alias(OUTPUT, "strips", INPUT)
      end

      ops.each do |op|
        op.temporary[:label_string] = "#{op.output_refs(OUTPUT)[0]} through #{op.output_refs(OUTPUT)[-1]}"
      end

      #ljklakjdlkaj
      #Ljlkj

      tokens = ops.first.output_tokens(OUTPUT)
      num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]

      grid = SVGGrid.new(num_samples, num_samples, 50, 50)
      num_samples.to_int.times.each do |i|
        _tokens = tokens.dup
        _tokens[-1] = i + 1
        grid.add(display_strip_panel(*_tokens, COLORS).scale!(0.5), i, i)
      end

      diluentATube = self.make_tube(closedtube, "Diluent A", ops.first.tube_label("diluent A"), "medium", true).scale!(0.75)
      stopTube = self.make_tube(closedtube, "Stop mix", ops.first.tube_label("stop"), "powder", true).scale!(0.75)
      goldTube = self.make_tube(closedtube, "Gold mix", ops.first.tube_label("gold"), "powder", true, fluidclass: "pinkfluid").scale!(0.75)
      diluentATube.translate!(50, 75)
      goldTube.align_with(diluentATube, 'top-right').translate!(50)
      stopTube.align_with(goldTube, 'top-right').translate!(50)
      img = SVGElement.new(children: [grid, diluentATube, goldTube, stopTube], boundx: 500, boundy: 220)
      img

      show_open_package(unit, "", NUM_SUB_PACKAGES) do
        note "Check that there are the following tubes and #{STRIPS}:"
        note display_svg(img, 1.0)
      end
    end

  end

  def rehydrate_stop_solution myops
    gops = group_packages(myops)
    gops.each do |unit, ops|
      from = ops.first.ref("diluent A")
      to = ops.first.ref("stop")
      show do
        raw transfer_title_proc(STOP_VOLUME, from, to)
        check "Centrifuge tube #{to} for 5 seconds to pull down powder."
        check "Set a #{P200_POST} pipette to [0 3 6]. Add #{STOP_VOLUME}uL from #{from.bold} into tube #{to.bold}"
        tubeA = make_tube(opentube, DILUENT_A, ops.first.tube_label("diluent A"), "medium")
        tubeS = make_tube(opentube, STOP_MIX, ops.first.tube_label("stop"), "powder")
        img = make_transfer(tubeA, tubeS, 200, "#{STOP_VOLUME}uL", "(#{P200_POST} pipette)")
        img.translate!(20)
        note display_svg(img, 0.75)
      end

      vortex_and_centrifuge_helper("tube",
                                   [to],
                                   VORTEX_TIME, CENTRIFUGE_TIME,
                                   "to mix.", "to pull down liquid", AREA, mynote = nil)
    end
  end

  def wait_for_pcr myops
    show do
      title "Wait for thermocycler to finish"

      note "The thermocycler containing the #{LIGATION_SAMPLE.pluralize(5)} needs to complete before continuing"
      check "Check the #{THERMOCYCLER} to see if the samples are done."
      bullet "If the cycle is at \"hold at 4C\" then it is done. If it is done, hit CANCEL followed by YES. If not, continue waiting."
      note "Else, if your ligation sample has been stored, retrieve from M20, 4th shelf down, green box."
      warning "Do not proceed until the #{THERMOCYCLER} is finished."
    end
  end

  def stop_ligation_product myops
    gops = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
    num_tubes = myops.inject(0) { |sum, op| sum + op.output_refs(OUTPUT).length }
    # ordered_ops = gops.map {|unit, ops| ops}.flatten.extend(OperationList) # organize by unit
    show do
      title "Take #{pluralizer("sample", num_tubes)} from the #{THERMOCYCLER} and place on rack in #{AREA.bold} area"
      check "Centrifuge for 5 seconds to pull down liquid"
      check "Place on rack in post-PCR area"

      gops.each do |unit, ops|
        ops.each do |op|
          note display_svg(display_ligation_tubes(*op.input_tokens(INPUT), COLORS), 0.75)
        end
      end
    end

    gops.each do |unit, ops|
      from = ops.first.ref("stop")
      ops.each do |op|
        to_labels = op.input_refs(INPUT)
        show do
          # title "Get ready to add #{STOP_MIX} to #{LIGATION_SAMPLE.pluralize(MUTATIONS.length)} for #{unit}"
          title "Position #{STOP_MIX} #{from.bold} and colored tubes #{op.input_refs(INPUT)[0].bold} to #{op.input_refs(INPUT)[-1].bold} in front of you."
          note "In the next steps you will add #{STOP_MIX} to #{pluralizer("tube", PREV_COMPONENTS.length)}"
          tube = closedtube.scale(0.75)
          tube.translate!(0, -50)
          tube = tube.g
          tube.g.boundx = 0
          labeled_tube = make_tube(closedtube, STOP_MIX, op.tube_label("stop"), "medium", true)
          ligation_tubes = display_ligation_tubes(*op.input_tokens(INPUT), COLORS)
          ligation_tubes.align!('bottom-left')
          ligation_tubes.align_with(tube, 'bottom-right')
          ligation_tubes.translate!(50)
          image = SVGElement.new(children: [labeled_tube, ligation_tubes], boundx: 600, boundy: tube.boundy)
          image.translate!(50)
          image.boundy = image.boundy + 50
          note display_svg(image, 0.75)
        end

        to_labels.each.with_index do |label, i|
          show do
            raw transfer_title_proc(STOP_TO_SAMPLE_VOLUME, from, label)
            # title "Add #{STOP_TO_SAMPLE_VOLUME}uL #{STOP_MIX} #{from.bold} to #{LIGATION_SAMPLE} #{label}"
            note "Set a #{P20_POST} pipette to [0 2 4]. Add #{STOP_TO_SAMPLE_VOLUME}uL from #{from.bold} into tube #{label.bold}"
            note "Close tube #{label}."
            note "Discard pipette tip."
            tubeS = make_tube(opentube, STOP_MIX, op.tube_label("stop"), "medium")
            transfer_image = transfer_to_ligation_tubes_with_highlight(
                tubeS, i, *op.input_tokens(INPUT), COLORS, STOP_TO_SAMPLE_VOLUME, "(#{P20_POST} pipette)")
            note display_svg(transfer_image, 0.75)
          end
        end
      end
    end
    
    show do
      title "Vortex and centrifuge all 12 tubes for 5 seconds."
      check "Vortex for 5 seconds."
      check "Centrifuge for 5 seconds."
      note "This step is important to avoid FALSE POSITIVE."
    end

    t = Table.new()
    t.add_column("STEP", ["Initial Melt", "Annealing"])
    t.add_column("TEMP", ["95C", "37C"])
    t.add_column("TIME", ["30s", "4 min"])
    add_to_thermocycler("tube", myops.length * PREV_COMPONENTS.length, STOP_CYCLE, t, "Stop Cycle")
  end

  def short_timer
    show do
      title "Set timer for 6 minutes"
      check "Set a timer for 6 minutes. This will notify you when the thermocycler is done."
      timer initialize: {minute: 6}
      check "Click the \"<b>play</b>\" button on the left. Proceed to next step now."
    end
  end

  def display_detection_strip_diagram
    show do
      title "Review detection #{STRIP} diagram"
      note "In the next steps you will be adding ligation mixtures followed by the gold solutions to the detection strips."
      note "You will pipette into the <b>Port</b>. After pipetting, you should see the <b>Reading Window</b> become wet after a few minutes."
      warning "Do not add liquid directly to the <b>Reading Window</b>"
      note display_svg(detection_strip_diagram, 0.75)
    end
  end

  def add_ligation_product_to_strips myops
    gops = group_packages(myops)

    show do
      title "Wait for stop cycle to finish (5 minutes)."
      check "Wait for the #{THERMOCYCLER} containing your samples to finish. "
      bullet "If the {THERMOCYCLER} beeps, it is done. If not, continue waiting."
      check "Once the #{THERMOCYCLER} finishes, IMMEDIATELY continue to the next step."
      check "Take all #{pluralizer("sample", myops.length * PREV_COMPONENTS.length)} from the #{THERMOCYCLER}."
      check "Vortex #{"sample".pluralize(PREV_COMPONENTS.length)} for 5 seconds to mix."
      check "Centrifuge #{"sample".pluralize(PREV_COMPONENTS.length)} for 5 seconds to pull down liquid"
      check "Place on rack in the #{POST_PCR.bold} area."
    end

    timer_set = false
    gops.each do |unit, ops|
      ops.each do |op|
        kit = op.temporary[:output_kit]
        sample = op.temporary[:output_sample]
        panel_unit = op.temporary[:output_unit]
        tube_unit = op.temporary[:input_unit]
        show do
          title "Arrange #{STRIPS} and tubes" # for sample 1?
          note "Place the detection #{STRIPS} and #{LIGATION_SAMPLE.pluralize(PREV_COMPONENTS.length)} as shown in the picture:"
          note display_svg(display_panel_and_tubes(kit, panel_unit, tube_unit, PREV_COMPONENTS, sample, COLORS).translate!(50), 0.6)
        end

        show do
          title "For each colored tube, add #{SAMPLE_TO_STRIP_VOLUME}uL of #{LIGATION_SAMPLE} to the sample port of each #{STRIP}."
          warning "<h2>Set a 5 minute timer after adding ligation sample to <b>FIRST A1</b> strip at the SAMPLE PORT.</h2>" unless timer_set
          warning "<h2>Add the rest of ligation samples to the rest of strips and then immediately click OK</h2>"
          timer_set = true
          #   check "Set a 5 minute timer" unless set_timer
          check "Set a #{P200_POST} pipette to [0 2 4]. Add #{SAMPLE_TO_STRIP_VOLUME}uL of <b>each</b> #{LIGATION_SAMPLE} to the corresponding #{STRIP}."
          note "Match the sample tube color with the #{STRIP} color. For example, match #{op.input_refs(INPUT)[0].bold} to #{op.output_refs(OUTPUT)[0].bold}"
        #   note "After adding the first sample, set the timer for 5 minutes"
          warning "Dispose of pipette tip and close tube after each strip."
          tubes = display_ligation_tubes(*op.input_tokens(INPUT), COLORS, (0..PREV_COMPONENTS.length - 1).to_a, [], 90)
          panel = display_strip_panel(*op.output_tokens(OUTPUT), COLORS)
          tubes.align_with(panel, 'center-bottom')
          tubes.align!('center-top')
          tubes.translate!(50, -50)
          img = SVGElement.new(children: [panel, tubes], boundy: 330, boundx: panel.boundx)
          note display_svg(img, 0.6)
        end
      end
    end
    show do
          title "Check to see if strips are wetting"
          note "You should see the strip become wet in reading window "
          note "If strips are not wetting after 2 minutes, contact #{SUPERVISOR}"
          warning "Do not continue until all strips are fully wet."
     end

  end

  def rehydrate_gold_solution myops
    gops = group_packages(myops)
    gops.each do |unit, ops|
      from = ops.first.ref("diluent A")
      to = ops.first.ref("gold")

      show do
        raw transfer_title_proc(GOLD_VOLUME, from, to)
        # title "Add #{GOLD_VOLUME}uL of #{DILUENT_A} #{from.bold} to #{GOLD_MIX} #{to.bold}"
        raw centrifuge_proc(GOLD_MIX, [to], CENTRIFUGE_TIME, "to pull down dried powder.", AREA)
        note "Set a #{P1000_POST} pipette to [ 0 6 0]. Add #{GOLD_VOLUME}uL from #{from.bold} into tube #{to.bold}."
        raw vortex_proc(GOLD_MIX, [to], "10 seconds", "to mix well.")
        warning "Make sure #{GOLD_MIX} is fully dissolved."
        warning "Do not centrifuge #{to.bold} after vortexing."
        tubeA = make_tube(opentube, DILUENT_A, ops.first.tube_label("diluent A"), "medium")
        tubeG = make_tube(opentube, GOLD_MIX, ops.first.tube_label("gold"), "powder", fluidclass: "pinkfluid")
        img = make_transfer(tubeA, tubeG, 200, "#{GOLD_VOLUME}uL", "(#{P1000_POST} pipette)")
        img.translate!(20)
        note display_svg(img, 0.75)
      end
    end
  end

  def add_gold_solution myops
    gops = group_packages(myops)
    set_timer = false

    show do
      title "Wait until 5 minute timer ends"
      warning "Do not proceed before 5 minute timer is up."
      note "The strips need a chance to become fully wet."
    end

    gops.each do |unit, ops|
        show do
            title "Add gold solution to #{pluralizer(STRIP, PREV_COMPONENTS.length * ops.length)}" 
            warning "<h2>Set a 10 minute timer after adding gold to <b>FIRST A1</b> strip at the SAMPLE PORT.</h2>"
            warning "<h2> Add gold to the rest of strips and then immediately click OK."
            warning "<h2> DO NOT add gold solution onto the reading window."
            check "Set a #{P200_POST} pipette to [0 4 0]. Transfer #{GOLD_TO_STRIP_VOLUME}uL of #{GOLD_MIX} #{ops.first.ref("gold").bold} to #{pluralizer(STRIP, PREV_COMPONENTS.length * ops.length)}."
            grid = SVGGrid.new(ops.length,  ops.length, 50, 50)
            ops.each.with_index do |op, i|
                _tokens = op.output_tokens(OUTPUT)
                grid.add(display_strip_panel(*_tokens, COLORS).scale!(0.5), i, i)
            end
            tubeG = make_tube(opentube, GOLD_MIX, ops.first.tube_label("gold"), "medium", fluidclass: "pinkfluid")
            img = make_transfer(tubeG, grid, 200, "#{GOLD_TO_STRIP_VOLUME}uL", "(each strip)")
            img.boundx = 900
            img.boundy = 400
            img.translate!(40)
            note display_svg(img, 0.6)
        end
      end
  end

  def read_from_scanner myops
    gops = group_packages(myops)
    show do
      title "Bring timer and #{pluralizer(STRIP, myops.length * PREV_COMPONENTS.length)} to the #{PHOTOCOPIER}."
      image "Actions/OLA/map_Klavins.svg" if KIT_NAME == "uw kit"
    end
    
    show do
      title "Wait until 10 minute timer is up"
      note "#{STRIPS.capitalize} need to rest for 10 minutes before taking an image."
      note "In the meantime, make sure you have access to the #{PHOTOCOPIER}."
      warning "<h2> Signal can develop more slowly if the room is humid. After the 10-min timer ends, you should see at least two lines on each strip. </h2>" 
      warning "If your signal is hard to see by eyes, give it another 5 minutes before clicking OK."
    end

    # show do
    #   title "IMPORTANT NOTE TO JUSTIN"
    #   warning "This protocol should be broken into two since technician will be moving from one computer to the next."
    #   note "This really depends on whether we want to use the laptop ONLY for detection purposes (I think we should)"
    # end

    myops.each do |op|
      op.temporary[:filename] = "#{op.output(OUTPUT).item.id}_#{op.temporary[:output_kit]}#{op.temporary[:output_sample]}"
    end

    gops.each do |unit, ops|
      ops.each do |op|
        labels = op.output_refs(OUTPUT)
        show do
          title "Scan #{STRIPS} <b>#{labels[0]} to #{labels[-1]}</b>"
          check "Open #{PHOTOCOPIER}"
          check "Place #{STRIPS} face down in the #{PHOTOCOPIER}"
          check "Align colored part of #{STRIPS} with the colored tape on the #{PHOTOCOPIER}"
          check "Close the #{PHOTOCOPIER}"
        end

        image_confirmed = false

        5.times.each do |this_try|
          unless image_confirmed
            show do
              title "Scan the image"
              check "Press the <b>\"AUTO SCAN\"</b> button firmly on the side of the #{PHOTOCOPIER} and hold for a few seonds. A new window should pop up, with a green bar indicating scanning in progress."
              check "Wait for #{PHOTOCOPIER} to complete. This takes about 1 minute."
            end

            rename = "<md-button ng-disabled=\"true\" class=\"md-raised\">rename</md-button>"
            copy = "<md-button ng-disabled=\"true\" class=\"md-raised\">copy</md-button>"
            paste = "<md-button ng-disabled=\"true\" class=\"md-raised\">paste</md-button>"

            show do
              title "Copy image file name #{op.temporary[:filename].bold}"
              note "1. highlight the file name: #{op.temporary[:filename].bold}"
              note "2. then click #{copy}"
              title "Then rename the new image file to #{op.temporary[:filename].bold}"
              note "1. a new file should appear on the desktop. Minimize this browser and find the new file."
              note "2. right-click and then click #{rename}"
              note "3. right-click and click #{paste} to rename file."
            end

            show_with_expected_uploads(op, op.temporary[:filename], SCANNED_IMAGE_UPLOAD_KEY) do
              title "Upload file <b>#{op.temporary[:filename]}</b>"
              note "Click the button below to upload file <b>#{op.temporary[:filename]}</b>"
              note "Navigate to the desktop. Click on file <b>#{op.temporary[:filename]}</b>"
            end

            confirmed = show do
              title "Confirm image labels say #{op.temporary[:label_string].bold}"
              select [ "yes", "no"], var: "confirmed", label: "Do the image labels and your image match?", default: 0
              img = display_strip_panel(*op.output_tokens(OUTPUT), COLORS).g
              img.boundy = 50
              note display_svg(img, 0.75)
              raw display_upload(op.temporary[SCANNED_IMAGE_UPLOAD_KEY])
            end

            image_confirmed = confirmed[:confirmed] == "yes"

            unless image_confirmed
              show do
                title "You selected that the images don't match!"
                note "You will now be asked to scan and upload the strip again."
              end
            end
          end
        end

        op.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, op.temporary[SCANNED_IMAGE_UPLOAD_KEY].id)
        op.output(OUTPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, op.temporary[SCANNED_IMAGE_UPLOAD_KEY].id)
      end
    end
  end
  
  def run_image_analysis ops
    image_result = nil
    warning_msg = nil
    5.times.each do |i|
        if image_result.nil?
            result = show do
                title "Run <b>OLA Image Processing</b>"
                warning warning_msg unless warning_msg.nil?
                note "Find the icon on the desktop labeled \"OLA IP\""
                image "Actions/OLA/ola_ip_logo.png" 
                note "Double click the icon."
                note "#{ops.first.temporary[SCANNED_IMAGE_UPLOAD_KEY].name}"
                joined_file_names = ops.map { |op| op.temporary[SCANNED_IMAGE_UPLOAD_KEY][:name] }.join(', ')
                note "Copy-and-paste the following into the text box: <b>#{joined_file_names}</b>"
                note "Click \"PROCESS\""
                note "Return here and press \"CONTROL+V\" to paste the text to the field below."
                get "text", var: :image_analysis_result, label: "Press CONTROL+V here to paste", default: ""
            end
            
            image_result = result[:image_analysis_result]
            if image_result == ""
                image_result = nil
                warning_msg = "Result was empty! Try again!"
            end
            
            if i >= 1
                image_result = "[]"
            end
        end
    end
    
    if image_result.nil?
        ops.each do |op|
            op.error(:image_result_failed, "Image processing has failed.") 
        end
    end
    
    ops.each do |op|
        op.associate(:image_processing_result, image_result)
        op.plan.associate(:image_processing_result, image_result)
    end
    
    show do
        title "Result has been sent!"
        note "You image processing result has been saved and emailed to the supervisor. Congrats! Below is the message that was sent."
        user = User.find_by_name("Nuttada Panpradist")
    
        tech = get_technician_name(self.jid)
        tech = User.find(66) unless tech.is_a?(User)
        kits = ops.map { |op| op.temporary[:input_kit] }
        samples = ops.map { |op| op.temporary[:input_sample] }
        subject = "Image processing result for #{tech.name}"
        message = "<p>Tech: #{tech.name} (#{tech.id})</p> " \
                "<p>Operations: #{ops.map { |op| op.id }}</p> " \
                "<p>Job: #{self.jid}</p>" \
                "<p>Kits: #{kits}</p> " \
                "<p>Samples: #{samples}</p> " \
                "<p>#{image_result}</p>"
        note "<b>#{subject}</b>"
        note message
        user.send_email(subject, message) unless debug
    end
  end
 
# def cleanup myops
#   show do
#     title "Cleanup"
#
#     check "After imaging #{pluralizer("strip", myops.length * MUTATIONS.length)}, you may discard strips and tubes " \
#             "into the biohazard waste."
#     check "Change gloves."
#   end
#   #   clean_area AREA
# end
#

  def cleanup myops
    def discard_refs_from_op(op)
      refs = []
      refs.push("Diluent A " + op.ref("diluent A").bold)
      refs.push("Gold Mix " + op.ref("gold").bold)
      refs.push("Stop Mix " + op.ref("stop").bold)
      unless KIT_NAME == "uw kit"
        refs.push("Samples #{op.input_refs(INPUT).join(', ').bold}")
      end
      refs
    end

    all_refs = myops.map {|op| discard_refs_from_op(op)}.flatten.uniq

    show do
      title "Throw items into the #{WASTE_POST}"

      #warning "Do not throw away the #{STRIPS}"
      note "Throw the following items into the #{WASTE_POST} in the #{AREA.bold} area:"
      t = Table.new
      t.add_column("Item to throw away", all_refs)
      table t
    end
    # clean_area AREA
  end

  def filename(op)
    item_id = op.output(OUTPUT).item.id
    labels = op.output_refs(OUTPUT)
    "#{labels[0]}_#{labels[-1]}_#{item_id}"
  end

  def conclusion myops
    #   if KIT_NAME == "uw kit"
    #      show do
    #         title "Please return ligation products"
    #         note "Please return the following to <b>M20 \"STORE USED 1C - 21C\"</b>"
    #         myops.each do |op|
    #             check "tubes #{op.temporary[:label_string].bold}" 
    #         end
    #         image "Actions/OLA/map_Klavins.svg"
    #      end
    #   end
    show do
      title "Thank you!"
      warning "<h2>You must click #{"OK".quote.bold} to complete the protocol</h2>"
      note "Please continue on to the next protocol. You will be ask to make visual calls for the detection strips."
    end
  end

end
```
