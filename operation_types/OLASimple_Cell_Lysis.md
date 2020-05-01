# OLASimple Cell Lysis

Blood CD4+ cells are negatively selected and lysed. Magnetic beads and antibodies are used to separate unwanted cells.
### Inputs


- **Whole Blood** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Whole Blood")'>OLA Whole Blood</a>



### Outputs


- **Lysed blood** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA lysed blood")'>OLA lysed blood</a>

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
# OLASimple EasySep
# author: Justin Vrana
# date: March 2018
#
#
##########################################

needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"
needs "OLASimple/JobComments"

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments

  ##########################################
  # INPUT/OUTPUT
  ##########################################

  INPUT = "Whole Blood"
  OUTPUT = "Lysed blood"
  KIT_NUM = "Kit Number"
  BLOOD_SAMPLE = "blood sample"

  ##########################################
  # COMPONENTS
  ##########################################


  BSC = "BSC"
  THIS_UNIT = "A"
  MAGNETIC_BEADS_COMPONENT = "A"
  ANTIBODIES_COMPONENT = "B"
  PBS_COMPONENT1 = "C"
  RBC_COMPONENT = "D"
  PBS_COMPONENT2 = "E"
  CD4_LYSIS = "F"
  TUBE1 = "G"
  TUBE2 = "H"
  TUBE3 = "J"
  TUBE4 = "K"

  PACK_HASH = {
      "Unit Name" => "A",
      "Components" => {
          "magnetic beads" => "A",
          "antibodies" => "B",
          "1X PBS 1" => "C",
          "RBC lysis buffer" => "D",
          "1X PBS 2" => "E",
          "CD4 lysis buffer" => "F",
          "sample tube 1" => "G",
          "sample tube 2" => "H",
          "sample tube 3" => "J",
          "sample tube 4" => "K"
      }
  }

  def main
    if operations.length > 2
      raise "Batch size > 2 is not supported for this protocol. Please rebatch."
    end
    operations.retrieve interactive: false
    save_user operations

    operations.each.with_index do |op, i|
      kit_num = op.input(INPUT).item.get(KIT_KEY)
      patient_id = op.input(INPUT).item.get(PATIENT_ID_KEY)
      if debug && kit_num.nil? && patient_id.nil?
        kit_num = rand(1..30)
        patient_id = rand(1..30)      
      end
      op.temporary[:input_kit] = kit_num
      op.temporary[:patient] = patient_id

      if op.temporary[:input_kit].nil?
        raise "Input kit number cannot be nil"
      end
      op.temporary[:input_sample] = i + 1
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
    
    # need to save :input_kit and :input_sample

    introduction
    safety_warning
    required_equipment
    additional_supplies

    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{BSC}"
    end

    show do
      title "Open package #{this_package}"
      note "There are two sub packages. Open sub packages."
      note "Arrange tubes on a plastic rack."
    end

    show do
      title "Spin down tubes"
      note "There should be 9 tubes with liquid and 8 empty tubes."
      note "Centrifuge the 9 tubes with liquid for <b>5 seconds</b> to pull down any fluid."
      note "Put tubes back on a plastic rack."
    end

    operations.running.each do |op|
      op.make_item_and_alias(OUTPUT, "sample tube 4", INPUT)
    end

    operations.running.each do |op|
      op.temporary[:blood_ref] = "#{op.temporary[:patient]}"
    end

    operations.running.each do |op|
      from = "#{op.temporary[:blood_ref]}"
      vol = 500
      show do
        title "Add #{vol.bold}uL of whole blood to empty tube #{op.ref("sample tube 1", true).bold}"
        note "Close both tubes after adding."
        tubeB = make_tube(opentube, "Blood", "#{from}", fluid = "medium", fluidclass: "redfluid")
        tubeE = make_tube(opentube, ["Empty", "tube"], op.tube_label("sample tube 1", true))
        img = make_transfer(tubeB, tubeE, 250, "#{vol}uL", "(#{P1000_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end

    show do
      title "Throw away blood samples"
      note "Dispose of blood samples #{operations.running.map {|op| op.temporary[:blood_ref].bold}.join(', ')} into biohazard waste."
    end


    operations.running.each do |op|
      vol = 25
      show do
        title "Add #{vol.bold}uL antibodies to tube #{op.ref("sample tube 1", true).bold}"
        note "Close both tubes after adding."
        tubeA = make_tube(opentube, "Antibodies", op.tube_label("antibodies"), fluid = "medium")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.tube_label("sample tube 1", true), fluid = "medium", fluidclass: "redfluid")
        img = make_transfer(tubeA, tubeS, 250, "#{vol}uL", "(#{P200_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end
    
    show do
        title "Vortex magnetic beads #{operations.running.map { |op| op.ref("magnetic beads").bold }.uniq.join(', ') } for 30 seconds as max speed"
    end

    operations.running.each do |op|
      vol = 25
      show do
        title "Add #{vol.bold}uL magnetic beads to tube #{op.ref("sample tube 1", true).bold}"
        note "Close both tubes after adding."
        tubeB = make_tube(opentube, ["Magnetic", "beads"], op.tube_label("magnetic beads"), fluid = "small", fluidclass: "brownfluid")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.tube_label("sample tube 1", true), fluid = "medium", fluidclass: "redfluid")
        img = make_transfer(tubeB, tubeS, 250, "#{vol}uL", "(#{P200_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end

    show do
      title "Mix blood"
      note "Close tubes"
      note "mix blood, antibody and magnetic bead mixture by gently pulse vortexing three times at low speed to avoid forming bubbles"
    end

    show do
      title "Incubate 5 min at room temperature in plastic rack"
      note "Set a 5 minute timer."
      note "Wait for 5 minute timer before continuing."
    end

    operations.running.each do |op|
      vol = 1000
      show do
        title "Add #{1000}uL 1X PBS to sample tube #{op.ref("sample tube 1", true).bold}"
        warning "Carefully mix by pipetting slowly up and down. Be careful not to overflow tube."
        note "Close both tubes after adding."
        tubeP = make_tube(opentube, "1X PBS", op.tube_label("1X PBS 1", true), fluid = "medium")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.tube_label("sample tube 1", true), fluid = "medium", fluidclass: "redfluid")
        img = make_transfer(tubeP, tubeS, 250, "#{vol}uL", "(#{P1000_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
        # transfer image
      end
    end

############################################
    # FIRST SEPARATION
############################################

    show do
      title "Magnetize samples"

      note "Move tube to the magnetic rack"
      note "Open tube caps"
      note "Set a timer for 5 minutes"
      note "Leave tubes to magnetize for 5 min at room temperature."
      bullet "Stagger the tubes so that the caps are not touching."
      warning "Image of tubes look like in a rack."
    end

    show do
      title "When timer expires, you will see dark material gathered on the side of the tube."
      # annotate this in image note "CD4+ cells are the light reddish-yellow liquid portion"
      warning "before and after IMAGES"
    end

    tubes = operations.running.map {|op| op.ref("sample tube 2", true)}

    show do
      title "Setup empty #{"tubes".pluralize(tubes)} #{tubes.join(', ').bold} on rack"
      note "Open tubes"
    end

    # show do
    #   title "Review the video below"
    #   note "In the next step, you will be transfering clear fluid to empty tube TUBE #2"
    #   note "You will hold the rack carefully without tilting rack"
    #   warning "You must pipette slowly and away from dark portion."
    #   warning "As liquid level decreases, the dark portion will \"droop\" and settle in the bottom of the tube."
    #   warning "VIDEO"
    # end

    operations.running.each do |op|
      show do
        title "Collect clear fluid from #{op.ref("sample tube 1", true)} and add to empty tube #{op.ref("sample tube 2", true).bold}"
        note "Use P1000 pipette set to 900uL"
        note "Point tip away from the dark portion and pipette up slowly."
        warning "Do not tilt the magnetic rack."
        tube = make_tube(opentube, ["empty", "tube"], op.tube_label("sample tube 2", true))
        img = make_transfer(sep_1_diagram, tube, 250, "900uL", P200_PRE)
        img.translate!(0, -100)
        note display_svg(img, 0.75)
        # warning "VIDEO HERE"
      end
    end

    # note "Use pipette to transfer clear fluid to empty TUBE #2"

    # title "Collect the clear fluid with P1000 set to 900l and transfer cell suspension to a new 2.0ml microfuge tube (TUBE #2)."
    # show do
    #   warning "IMAGE HERE"
    #   bullet "Pipet slowly pointing the tip to the wall away from the magnetized red cell portion"
    #   bullet "set the pipette tip just under the surface of the cell suspension (* in the image), and slowly begin to draw the liquid up, keeping the distance "
    #   # "between the pipette tip and the top of the liquid constant as you draw the liquid up by slowly lowering as you draw up more volume [video 2]"
    #   warning "As liquid level decreases, the dark red portion will begin to \"droop\" and settle in the bottom of the tube."
    #   note "If any clear liquid left behind, use the same pipette tip to draw as much of the non-red material as possible."
    #   warning "when drawing up the cell suspension, stop immediately if a flash of bright red appears in your pipette tip"
    #   warning "image of TUBE #1 after cell suspension has been collected [image 4]"
    # end

    # batch all steps by sample
    
############################################
    # SECOND SEPARATION
############################################

    operations.running.each do |op|
      vol = 25
      show do
        title "Add #{vol.bold}uL magnetic beads to cell suspension #{op.ref("sample tube 2", true).bold}"
        note "Quickly vortex magnetic beads before adding."
        note "Close both tubes after adding."
        note "Pulse vortex at low speed for 3 seconds to mix."
        tubeB = make_tube(opentube, ["Magnetic", "beads"], op.tube_label("magnetic beads"), fluid = "small", fluidclass: "brownfluid")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.tube_label("sample tube 2", true), fluid = "large", fluidclass: "palefluid")
        img = make_transfer(tubeB, tubeS, 250, "#{vol}uL", "(#{P200_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end

    tubes = operations.running.map {|op| op.ref("sample tube 2", true)}
    remove_tubes = operations.running.map {|op| op.ref("sample tube 1", true)}
    show do
      title "Incubate cell and bead mixtures for 5 min at room temperature on plastic tube rack"
      warning "Do not add tubes #{tubes.join(', ')} to magnetic rack yet."
      note "Cap old tubes #{remove_tubes.join(', ').bold}, remove from magnetic rack and discard."
      note "Set timer for 5 minutes."
      # timer initialize: {timer: 5}
    end

    show do
      title "After 5 minute incubation, add cell suspensions #{tubes.join(', ')} to magnetic rack"
      note "Open caps of tubes."
      note "Magnetize for 5 min at room temperature."
      note "Set timer for 5 minutes"
    end
    # [image 5] [image 6] [video 4]

    operations.running.each do |op|
      show do
        title "After 5 minutes, collect clear fluid from #{op.ref("sample tube 2", true)} and add to empty tube #{op.ref("sample tube 3", true).bold}"
        note "Use P1000 pipette set to 900uL"
        note "Point tip away from the dark portion and pipette up slowly."
        warning "Do not tilt the magnetic rack."
        tube = make_tube(opentube, ["empty", "tube"], op.tube_label("sample tube 3", true))
        img = make_transfer(sep_2_diagram, tube, 250, "900uL", P1000_PRE)
        img.translate!(0, -100)
        note display_svg(img, 0.75)
        # warning "VIDEO HERE"
      end
    end

############################################
    # THIRD (FINAL) SEPARATION
############################################


    # show do
    #     title "Transfer cell suspension from 2.0ml TUBE #2 on the magnetic rack to a new 1.5ml microfuge tube (1.5ml TUBE #3) using a P1000 set to 1000l of"
    #     note "use same pipet tip to collect any remaining liquid without disturbing magnetized fraction"
    #     bullet "pipette along the inside of the tube farthest from the magnet"
    #     bullet "magnetized material should be significantly smaller this time which means should be able to collect all liquid without disturbing magnetized portion"
    #     #	video of collecting cell suspension [video 5]
    # end
    
    operations.running.each do |op|
      vol = 25
      show do
        title "Add #{vol.bold}uL magnetic beads to cell suspension #{op.ref("sample tube 3", true).bold}"
        note "Quickly vortex magnetic beads before adding."
        note "Close both tubes after adding."
        note "Pulse vortex at low speed for 3 seconds to mix."
        tubeB = make_tube(opentube, ["Magnetic", "beads"], op.tube_label("magnetic beads"), fluid = "small", fluidclass: "brownfluid")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.tube_label("sample tube 3", true), fluid = "large", fluidclass: "palefluid")
        img = make_transfer(tubeB, tubeS, 250, "#{vol}uL", "(#{P200_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end
    
    tubes = operations.running.map {|op| op.ref("sample tube 3", true)}
    remove_tubes = operations.running.map {|op| op.ref("sample tube 2", true)}
    show do
      title "Incubate cell and bead mixtures for 5 min at room temperature on plastic tube rack"
      warning "Do not add tubes #{tubes.join(', ')} to magnetic rack yet."
      note "Cap old tubes #{remove_tubes.join(', ').bold}, remove from magnetic rack and discard."
      note "Set timer for 5 minutes."
      # timer initialize: {timer: 5}
    end

    show do
      title "After 5 minute incubation, add cell suspensions #{tubes.join(', ')} to magnetic rack"
      bullet "This is the final separation. There should be very little cells left to separate."
      note "Open caps of tubes."
      note "Magnetize for 5 min at room temperature."
      note "Set timer for 5 minutes"
    end

    operations.running.each do |op|
      show do
        title "After 5 minutes, add all remaining fluid from #{op.ref("sample tube 3", true)} and add to empty tube #{op.output_ref(OUTPUT).bold}"
        note "Use P1000 pipette set to 900uL"
        bullet "pipette along the inside of the tube farthest from the magnet"
        bullet "magnetized material should be significantly smaller this time which means should be able to collect all liquid without disturbing magnetized portion"
        tube = make_tube(opentube, ["empty", "tube"], op.output_tube_label(OUTPUT))
        img = make_transfer(sep_3_diagram, tube, 250, "all remaining fluid", "(P1000 pipette)")
        img.translate!(0, -100)
        note display_svg(img, 0.75)
        # warning "VIDEO HERE"
      end
    end

    # show do
    #     title "Transfer all remaining liquid to new 1.5ml tube (1.5ml TUBE #4) using P1000 [video 6]"
    #     bullet "pipette along the inside of 1.5ml TUBE #3 farthest from the magnet"
    #     bullet "1.5ml TUBE #4 now contains your final cell suspension"
    #     bullet "cap and discard 1.5ml TUBE #3"
    # end

    output_samples = operations.running.map { |op| op.output_ref(OUTPUT) }

    show do
      title "Centrifuge #{output_samples.join(', ').bold} in a microcentrifuge to pellet cells"
      warning "Remember samples are still infectious!"
      note "Add samples #{output_samples.join(', ').bold} centrifuge"
      note "Set centrifuge <b>10,000 RPM</b>"
      note "Centrifuge for <b>1.5 minutes</b>"
      warning "Balance tubes on opposite sides of the centrifuge"
      # note to say balance
    end
    
    show do
        title "Return samples from centrifuge to BSC"
        warning "Remember samples are still infectious!"
    end

    show do
      title "In the BSC, remove fluid from cell pellets carefully discard supernatant fluid."
      note "Visually confirm there are cell pellets for the tubes."
      bullet "These pellets contain CD4+ cells and red blood cells"
      warning "Try not to disturb cell pellet"
      note "Remove the fluid from the cell pellet. Discard fluid into bleach."
      warning "Change pipette tip between samples."
    end
    
    operations.running.each do |op|
      vol = 1000
      show do
        title "Add #{vol.bold}uL RBC lysis buffer to tube #{op.output_ref(OUTPUT).bold}"
        note "Close both tubes after adding."
        note "Gently pulse vortex at low speed to resuspend the cell pellet."
        tubeA = make_tube(opentube, ["Lysis", "buffer"], op.tube_label("RBC lysis buffer", true), fluid = "medium")
        tubeS = make_tube(opentube, ["Red blood", "cell pellet"], op.output_tube_label(OUTPUT), fluid = "powder", fluidclass: "palefluid")
        img = make_transfer(tubeA, tubeS, 250, "#{vol}uL", "(#{P1000_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
      end
    end

    show do
      title "Incubate samples on a plastic rack for 3 min at room temperature to lyse red blood cells"
      note "The lysis buffer will kill off red blood cells, leaving the CD4+ cells"
      note "Set a timer for 3 minutes."
    end

    show do
      title "Centrifuge #{output_samples.join(', ').bold} in a microcentrifuge to pellet CD4+ cells"
      warning "Remember samples are still infectious!"
      note "Add samples #{output_samples.join(', ').bold} centrifuge"
      warning "Balance tubes on opposite sides of the centrifuge"
      note "Set centrifuge <b>10,000 RPM</b>"
      note "Centrifuge for <b>1.5 minutes</b>"
    end
    
    show do
        title "Return samples to BSC and remove fluid"
        note "Using #{P1000_PRE} pipette set to 900uL, remove fluid from cell pellet."
        note "Discard fluid into bleach"
        warning "Change pipette tip between samples."
    end

    operations.running.each do |op|
      vol = 1000
      show do
        title "Add #{1000}uL 1X PBS to tube #{op.output_ref(OUTPUT).bold} to wash cells"
        warning "Carefully mix by pipetting slowly up and down. Be careful not to overflow tube."
        note "Close both tubes after adding."
        note "Gently pulse vortex at low speed to resuspend cells."
        tubeP = make_tube(opentube, "1X PBS", op.tube_label("1X PBS 2", true), fluid = "medium")
        tubeS = make_tube(opentube, ["Sample", "tube"], op.output_tube_label(OUTPUT), fluid = "powder", fluidclass: "palefluid")
        img = make_transfer(tubeP, tubeS, 250, "#{vol}uL", "(#{P1000_PRE} pipette)")
        img.translate!(25)
        note display_svg(img, 0.75)
        # transfer image
      end
    end

    show do
      title "Centrifuge #{output_samples.join(', ').bold} in a microcentrifuge to pellet CD4+ cells"
      warning "Remember samples are still infectious!"
      note "Add samples #{output_samples.join(', ').bold} centrifuge"
      warning "Balance tubes on opposite sides of the centrifuge"
      note "Set centrifuge <b>10,000 RPM</b>"
      note "Centrifuge for <b>1.5 minutes</b>"
    end

    show do
      title "Return samples to BSC and remove all residual fluid."
      note "Use a P1000 set to 950ul to slowly draw up PBS superntant without disturbing the cell pellet."
      note "Use a P200 carefully remove all residual fluid making sure you don't touch the cells."
      note "Discard all fluid into bleach."
      warning "Cell pellet may be difficult to see, so pipette slowly to avoid disturbing cells"
      # warning "video of PBS removal after 1 min at 10,000 rpm spin [video 9]"
    end

    show do
      title "Contact #{SUPERVISOR} once you have reached this step."
      note "Make sure #{SUPERVISOR} adds proteinaseK to your tubes #{output_samples.join(', ').bold}."
    end

    show do
      title "Add 30l of lysis buffer/proteinaseK to tubes #{output_samples.join(', ').bold}"
      note "CLose tube and gently pulse vortex three times at low speed to resuspend the cell pellet"
      warning "Try not to introduce air bubbles."
    end

    show do
      title "Incubate samples for 10 min at 56C to lyse cells "
      note "Add samples #{output_samples.join(', ').bold} to 56C heat block."
      note "Set a timer for 10 minutes and wait."
    end

    show do
      title "Incubate for 5 min at 95C to heat deactivate proteinase K"
      note "Before adding samples, quick spin samples for 5 seconds."
      note "Add samples #{output_samples.join(', ').bold} to 95C heat block."
      note "Set a timer for 5 minutes and wait."
    end

    show do
      title "Quick spin the tubes"
      note "Spin samples for a few seconds to collect lysate and any condensation at the bottom of the tube"
      note "Let tube cool to room temperature and give to #{SUPERVISOR}."
      # note "Let tube cool to room temperature and proceed with PCR, or store lysate at -20C for later use."
    end

    show do
      title "Clean up Waste"
      bullet "Dispose of liquid waste in bleach down the sink with running water."
      bullet "Dispose of remaining tubes into biohazard waste."
    end

    show do
      title "Clean Biosafety Cabinet"
      note "Place items in the BSC off to the side."
      note "Spray down surface of BSC with 10% bleach. Wipe clean using paper towel."
      note "Spray down surface of BSC with 70% ethanol. Wipe clean using paper towel."
      note "After cleaning, dispose of gloves in biohazard waste."
    end


    # put down clean_area method here
    # after cleaning dispose of gloves into biohazard
    
    accept_comments
    return {}

  end

  def save_user ops
    ops.each do |op|
      username = get_technician_name(self.jid)
      op.associate(:technician, username)
    end
  end

  def introduction
    show do
      title "Welcome to OLASimple Cell Lysis"

      note "In this protocol Blood CD4+ cells will be negatively selected and lysed. "
      note "You will use magnetic beads and antibodies to separate unwanted cells using a magnet. " \
          "You will repeat the magnetic separation for a total of 3 passes until all red material is removed."
      note "The separation leaves CD4+ and red blood cells (RBC) in the suspension."
      note display_svg(negative_selection_diagram, 1.0)
    end

    show do
      title "Welcome to OLASimple Cell Lysis"
      note "After separation, target CD4+ cells containing the HIV DNA will be in the clear fluid."
      note "Unwanted red blood cells will be lysed, leaving CD+ cells."
      note "Finally, CD+ cells will be lysed to release the DNA."
      note "This DNA will be used to detect HIV mutations."
    end
  end

  # TODO: add goggles?
  def safety_warning
    show do
      title "Review the safety warnings"
      warning "You will be working with infectious materials."
      note "Do <b>ALL</b> work in a biosafety cabinet (#{BSC.bold})"
      note "Always wear a lab coat and gloves for this protocol."
      check "Put on a lab coat and gloves now."
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
          "magnetic rack",
          "vortex mixer",
          "tube rack",
          "timer",
          "bleach in a beaker",
          "70% v/v ethanol"
      ]
      materials.each do |m|
        check m
      end
    end
  end

  def additional_supplies
    show do
      title "Make sure heat blocks are set to 56C and 95C"
    end
  end

  def get_package myops
    show do
      title "Get package"
      warning "This step will ask tech to get the appropriate package."
    end
  end

  def open_package myops
    show do
      title "Open package"
      warning "This step will show a picture of the materials and ask tech to verify there are the right tubes."
    end
  end

  def sep_1_diagram
    img = SVGElement.new(boundx: 113, boundy: 394)
    img.add_child(<<EOF
      <g id="OpenLid">
	<g>
		<path fill="#F7FCFE" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795c0.375,1.254,0.75,2.506,1.125,3.76
			c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699C84.416,163.427,85.342,171.819,81.992,179.294z"
			/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795
			c0.375,1.254,0.75,2.506,1.125,3.76c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699
			C84.416,163.427,85.342,171.819,81.992,179.294z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688c1.1,0,2-0.535,2-1.188
			c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188s-0.9-1.188-2-1.188
			H66.292z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688
			c1.1,0,2-0.535,2-1.188c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188
			s-0.9-1.188-2-1.188H66.292z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148
			c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3L86.186,102.598z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471
			c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3
			L86.186,102.598z"/>
	</g>
	<line fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" x1="69.979" y1="149.319" x2="69.979" y2="116.069"/>
</g>
<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M18.856,196.703v45.309l14.998,90.066c0,4.35,5.037,7.875,11.25,7.875
	c6.215,0,11.25-3.525,11.25-7.875l15-90.066v-45.309H18.856z"/>
<rect x="74.021" y="196.849" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M45.104,340.362c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		v-20.619c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C33.854,336.837,38.891,340.362,45.104,340.362z"/>
</g>
<text transform="matrix(1 0 0 1 11.3271 382.2627)" font-family="'MyriadPro-Regular'" font-size="25">Avoid</text>
<polygon fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" points="28.413,242.103 21.005,240.936 42.632,10.692 
	76.217,15.988 "/>
<g>
	<path fill="#F1F2F2" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z
		"/>
	<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875
		c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z"/>
</g>
<g>
	<path id="smallgoop_1_" fill="#BE1E2D" d="M58.038,318.527c-0.48,0.29-0.853,0.667-1.167,1.104
		c-0.286,0.446-0.544,0.889-0.791,1.329c-0.345,0.425-0.624,0.832-0.864,1.229c-0.991,1.92-1.5,3.797-3.802,6.113
		c-0.326,0.24-0.664,0.473-1.014,0.702c-1.255,0.63-3.409,1.163-3.962,1.811c-0.864,0.87,0.737,0.984,2.856,0.351
		c2.816-0.787,5.354-1.938,7.215-3.107c0.564-0.939,0.878-1.972,0.878-3.055l1.118-6.713
		C58.341,318.363,58.183,318.44,58.038,318.527z"/>
</g>
<g>
	<path id="mediumgoop_1_" fill="#BE1E2D" d="M62.865,284.622c-1.722-0.176-2.978,0.252-3.904,1.139
		c-0.927,0.885-1.526,2.229-1.938,3.883c-0.338,1.717-0.611,3.434-0.859,5.154c-0.497,1.574-0.849,3.123-1.115,4.66
		c-0.877,7.564-0.631,15.314-4.343,23.576c-0.596,0.789-1.225,1.533-1.886,2.254c-2.521,1.754-7.274,2.385-8.095,4.764
		c-1.395,3.105,2.541,4.854,7.132,3.756c3.25-0.641,6.229-1.791,8.848-3.264c0.022-0.203,0.044-0.406,0.044-0.613l7.516-45.127
		C63.821,284.724,63.36,284.657,62.865,284.622z"/>
</g>
<g>
<path id="largegoop_1_" fill="#BE1E2D" d="M70.233,227.925c-0.539-0.592-1.101-1.156-1.7-1.677
		c-2.18-1.891-4.767-3.295-7.818-4.106c-3.108-0.959-5.194-0.299-6.55,1.576c-1.355,1.877-1.983,4.971-2.176,8.881
		c-0.043,4.081,0.029,8.187,0.148,12.31c-0.371,3.683-0.492,7.357-0.467,11.022c0.897,18.184,3.846,37.165-0.056,56.177
		c-0.8,1.744-1.673,3.365-2.61,4.925c-3.899,3.502-12.119,3.583-12.802,9.137c-1.465,7.144,6.075,12.614,13.855,11.348
		c1.231-0.126,2.429-0.324,3.597-0.573c0.996-1.113,1.578-2.408,1.578-3.796l15-85.266V227.925z"/>
</g>
<g>
	<polygon stroke="#000000" stroke-miterlimit="10" points="52.353,334.137 44.153,331.308 50.704,323.193 	"/>
	<line fill="none" stroke="#000000" stroke-width="3" stroke-miterlimit="10" x1="48.61" y1="331.569" x2="41.199" y2="361.209"/>
</g>
EOF
    )
    img
  end

  def sep_2_diagram
    img = SVGElement.new(boundx: 113, boundy: 394)
    img.add_child(<<EOF
      <g id="OpenLid">
	<g>
		<path fill="#F7FCFE" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795c0.375,1.254,0.75,2.506,1.125,3.76
			c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699C84.416,163.427,85.342,171.819,81.992,179.294z"
			/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795
			c0.375,1.254,0.75,2.506,1.125,3.76c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699
			C84.416,163.427,85.342,171.819,81.992,179.294z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688c1.1,0,2-0.535,2-1.188
			c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188s-0.9-1.188-2-1.188
			H66.292z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688
			c1.1,0,2-0.535,2-1.188c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188
			s-0.9-1.188-2-1.188H66.292z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148
			c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3L86.186,102.598z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471
			c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3
			L86.186,102.598z"/>
	</g>
	<line fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" x1="69.979" y1="149.319" x2="69.979" y2="116.069"/>
</g>
<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M18.856,196.703v45.309l14.998,90.066c0,4.35,5.037,7.875,11.25,7.875
	c6.215,0,11.25-3.525,11.25-7.875l15-90.066v-45.309H18.856z"/>
<rect x="74.021" y="196.849" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M45.104,340.362c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		v-20.619c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C33.854,336.837,38.891,340.362,45.104,340.362z"/>
</g>
<text transform="matrix(1 0 0 1 11.3271 382.2627)" font-family="'MyriadPro-Regular'" font-size="25">Avoid</text>
<polygon fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" points="28.413,242.103 21.005,240.936 42.632,10.692 
	76.217,15.988 "/>
<g>
	<path fill="#F1F2F2" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z
		"/>
	<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875
		c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z"/>
</g>
<g>
	<path id="mediumgoop_1_" fill="#BE1E2D" d="M62.865,284.622c-1.722-0.176-2.978,0.252-3.904,1.139
		c-0.927,0.885-1.526,2.229-1.938,3.883c-0.338,1.717-0.611,3.434-0.859,5.154c-0.497,1.574-0.849,3.123-1.115,4.66
		c-0.877,7.564-0.631,15.314-4.343,23.576c-0.596,0.789-1.225,1.533-1.886,2.254c-2.521,1.754-7.274,2.385-8.095,4.764
		c-1.395,3.105,2.541,4.854,7.132,3.756c3.25-0.641,6.229-1.791,8.848-3.264c0.022-0.203,0.044-0.406,0.044-0.613l7.516-45.127
		C63.821,284.724,63.36,284.657,62.865,284.622z"/>
</g>
<g>
	<polygon stroke="#000000" stroke-miterlimit="10" points="52.353,334.137 44.153,331.308 50.704,323.193 	"/>
	<line fill="none" stroke="#000000" stroke-width="3" stroke-miterlimit="10" x1="48.61" y1="331.569" x2="41.199" y2="361.209"/>
</g>
EOF
    )
    img
  end

  def sep_3_diagram
    img = SVGElement.new(boundx: 113, boundy: 394)
    img.add_child(<<EOF
      <g id="OpenLid">
	<g>
		<path fill="#F7FCFE" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795c0.375,1.254,0.75,2.506,1.125,3.76
			c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699C84.416,163.427,85.342,171.819,81.992,179.294z"
			/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M81.992,179.294c-3.271,7.512-10.103,12.477-16.997,13.795
			c0.375,1.254,0.75,2.506,1.125,3.76c17.403-5.207,26.03-24.734,18.165-41.105c-1.178,0.566-2.357,1.133-3.537,1.699
			C84.416,163.427,85.342,171.819,81.992,179.294z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688c1.1,0,2-0.535,2-1.188
			c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188s-0.9-1.188-2-1.188
			H66.292z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M66.292,111.973c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688
			c1.1,0,2-0.535,2-1.188c0-0.654,0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188
			s-0.9-1.188-2-1.188H66.292z"/>
	</g>
	<g>
		<path fill="#F7FCFE" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148
			c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3L86.186,102.598z"/>
		<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M86.186,102.598c0.953-0.55,1.732-0.1,1.732,1v55.471
			c0,1.1-0.846,2.311-1.877,2.689l-3.121,1.148c-1.033,0.381-1.877-0.209-1.877-1.309v-54.03c0-1.1,0.779-2.45,1.73-3
			L86.186,102.598z"/>
	</g>
	<line fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" x1="69.979" y1="149.319" x2="69.979" y2="116.069"/>
</g>
<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M18.856,196.703v45.309l14.998,90.066c0,4.35,5.037,7.875,11.25,7.875
	c6.215,0,11.25-3.525,11.25-7.875l15-90.066v-45.309H18.856z"/>
<rect x="74.021" y="196.849" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M45.104,340.362c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		v-20.619c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C33.854,336.837,38.891,340.362,45.104,340.362z"/>
</g>
<text transform="matrix(1 0 0 1 11.3271 382.2627)" font-family="'MyriadPro-Regular'" font-size="25">Avoid</text>
<polygon fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" points="28.413,242.103 21.005,240.936 42.632,10.692 
	76.217,15.988 "/>
<g>
	<path fill="#F1F2F2" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z
		"/>
	<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M76.104,192.703c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875
		c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V192.703z"/>
</g>
<g>
	<path id="smallgoop_1_" fill="#BE1E2D" d="M58.038,318.527c-0.48,0.29-0.853,0.667-1.167,1.104
		c-0.286,0.446-0.544,0.889-0.791,1.329c-0.345,0.425-0.624,0.832-0.864,1.229c-0.991,1.92-1.5,3.797-3.802,6.113
		c-0.326,0.24-0.664,0.473-1.014,0.702c-1.255,0.63-3.409,1.163-3.962,1.811c-0.864,0.87,0.737,0.984,2.856,0.351
		c2.816-0.787,5.354-1.938,7.215-3.107c0.564-0.939,0.878-1.972,0.878-3.055l1.118-6.713
		C58.341,318.363,58.183,318.44,58.038,318.527z"/>
</g>
<g>
	<polygon stroke="#000000" stroke-miterlimit="10" points="52.353,334.137 44.153,331.308 50.704,323.193 	"/>
	<line fill="none" stroke="#000000" stroke-width="3" stroke-miterlimit="10" x1="48.61" y1="331.569" x2="41.199" y2="361.209"/>
</g>
EOF
    )
    img
  end

end

```
