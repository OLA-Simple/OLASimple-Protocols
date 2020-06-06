# OLASimple PCR

Generate PCR products from cell lysate which will be used later to detect HIV mutations.
### Inputs


- **Patient Sample** [P]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA viral RNA")'>OLA viral RNA</a>



### Outputs


- **PCR Product** [P]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA PCR")'>OLA PCR</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
eval Library.find_by_name("OLAScheduling").code("source").content
extend OLAScheduling

def precondition(op)
  schedule_same_kit_ops(op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# frozen_string_literal: true

##########################################
#
#
# OLASimple PCR
# author: Justin Vrana
# date: March 2018
#
#
##########################################

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments
  include OLAKitIDs

  ##########################################
  # INPUT/OUTPUT
  ##########################################
  INPUT = 'Patient Sample'
  OUTPUT = 'PCR Product'
  PACK = 'PCR Pack'
  A = 'Diluent A'

  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################

  PACK_HASH = PCR_UNIT
  AREA = PRE_PCR
  SAMPLE_VOLUME = 10 # volume of sample to add to PCR mix
  PCR_MIX_VOLUME = PACK_HASH['PCR Rehydration Volume'] # volume of water to rehydrate PCR mix in
  CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = '5 seconds' # time to pulse vortex to mix

  # for debugging
  PREV_COMPONENT = '6'
  PREV_UNIT = 'E'

  TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'

  component_to_name_hash = {
    'diluent A' => 'Diluent A',
    'sample tube' => 'PCR sample'
  }

  MATERIALS = [
    'P200 pipette and filtered tips',
    'P20 pipette and filtered tips',
    'a timer',
    'nitrile gloves (wear tight gloves to reduce contamination risk)',
    'pre-PCR rack',
    'a balancing tube (on rack)',
    'biohazard waste (red bag)',
    'vortex',
    'centrifuge'
  ].freeze

  SAMPLE_ALIAS = 'RNA Extract'

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################

  def main
    operations.running.retrieve interactive: false
    operations.running.make
    save_user operations
    debug_setup(operations) if debug

    if debug
      labels = %w[001 002]
      operations.each.with_index do |op, i|
        op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
        op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
        op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
      end
    end

    save_temporary_input_values(operations, INPUT)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)

    run_checks(operations)
    kit_introduction(operations.running)
    record_technician_id
    safety_warning
    area_preparation('pre-PCR', MATERIALS, POST_PCR)
    simple_clean("OLASimple PCR")
    get_inputs(operations.running)
    validate_pcr_inputs(operations.running)
    get_pcr_packages(operations.running)
    validate_pcr_packages(operations.running)
    open_pcr_packages(operations.running)
    debug_table(operations.running)
    # check_for_tube_defects sorted_ops.running
    # nuttada thaw
    # nuttada needs vortex + centrigure
    centrifuge_samples(sorted_ops.running)
    resuspend_pcr_mix(sorted_ops.running)
    add_template_to_master_mix(sorted_ops.running)
    cleanup(sorted_ops)
    start_thermocycler(sorted_ops.running)
    wash_self
    accept_comments
    conclusion(sorted_ops)
    {}
  end # main

  # end of main

  #######################################
  # Utilities
  #######################################
  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end

  def debug_setup(ops)
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
        alias_array[3] = if alias_array[3] == 1
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

  def run_checks(_myops)
    if operations.running.empty?
      show do
        title 'All operations have errored'
        note "Contact #{SUPERVISOR}"
        operations.each do |op|
          note (op.errors.map { |k, v| [k, v] }).to_s
        end
      end
      {}
    end
  end

  def sorted_ops
    operations.sort_by { |op| op.output_ref(OUTPUT) }.extend(OperationList)
  end

  #######################################
  # Instructions
  #######################################

  def kit_introduction(ops)
    show do
      title "Welcome to OLASimple PCR"
      note 'You will be running the OLASimple PCR protocol. You will start with RNA Extraction products and will generate PCR products from the samples and use them later to detect HIV mutations.'
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

  def get_inputs(myops)
    gops = group_packages(myops)

    show do
      title "Place #{SAMPLE_ALIAS.bold} samples in #{AREA.bold}."
      note "Retrieve from cold rack and place the following #{SAMPLE_ALIAS.bold} samples into a rack in the #{AREA.bold} area."
      note 'Samples may also be in the -20 freezer if this protocol has been delayed.'
      tubes = []
      gops.each do |unit, ops|
        ops.each_with_index do |op, i|
          tubes << make_tube(closedtube, '', ref(op.input(INPUT).item).split('-'), 'medium', true).translate!(100 * i)
        end
        img = SVGElement.new(children: tubes, boundy: 300, boundx: 300).translate!(20)
        note display_svg(img)
      end
    end
  end

  def validate_pcr_inputs(myops)
    expected_inputs = myops.map { |op| ref(op.input(INPUT).item).sub("-","") }
    sample_validation_with_multiple_tries(expected_inputs)
  end

  def get_pcr_packages(myops)
    # TODO: remove all references to 4C fridge and replace with refridgerator
    gops = group_packages(myops)
    show do
      title "Take #{PCR_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{AREA}"
      # check "Take the following from the #{FRIDGE} and place #{pluralizer(PACKAGE, gops.length)} on the #{BENCH}"
      gops.each do |unit, _ops|
        check 'Take package ' "#{unit.bold}" ' from fridge.'
        check 'Place package ' "#{unit.bold}" ' on the bench.'
        check 'Remove the <b>outside layer</b> of gloves (since you just touched the door knob).'
        check 'Put on a new outside layer of gloves.'
      end
    end
  end

  def validate_pcr_packages(myops)
    group_packages(myops).each { |unit, _ops| package_validation_with_multiple_tries(unit) }
  end

  def open_pcr_packages(myops)
    grouped_by_unit = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
    grouped_by_unit.each do |kit_and_unit, ops|
      ops.each do |op|
        op.make_item_and_alias(OUTPUT, 'sample tube', INPUT)
      end

      show_open_package(kit_and_unit, '', ops.first.temporary[:pack_hash][NUM_SUB_PACKAGES_FIELD_VALUE]) do
        # img
        pcr_tube_labels = ops.map { |op| op.output_tube_label(OUTPUT) }

        num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        kit, unit, component, sample = ops.first.output_tokens(OUTPUT)
        # diluentATube = label_tube(closedtube, tube_label(kit, unit, diluentAcomponent, ""))
        diluentATube = make_tube(closedtube, 'Diluent A', ops.first.tube_label('diluent A'), 'medium', true)

        grid = SVGGrid.new(num_samples, 1, 75, 10)
        pcr_tube_labels.each_with_index do |tube_label, i|
          pcrtube = make_tube(closedtube, '', tube_label, 'powder', true).scale(0.75)
          grid.add(pcrtube, i, 0)
        end
        grid.boundy = closedtube.boundy * 0.75
        grid.align_with(diluentATube, 'center-right')
        grid.align!('center-left')
        grid.translate!(25, 25)
        img = SVGElement.new(children: [diluentATube, grid], boundy: diluentATube.boundy + 50, boundx: 300).translate!(20)

        check "Look for #{num_samples + 1} #{'tube'.pluralize(num_samples)}"
        check 'Place tubes on a rack'
        note display_svg(img, 0.75)
      end
    end
  end

  def debug_table(myops)
    if debug
      show do
        title 'DEBUG: I/O Table'

        table myops.running.start_table
                   .custom_column(heading: 'Input Kit') { |op| op.temporary[:input_kit] }
                   .custom_column(heading: 'Output Kit') { |op| op.temporary[:output_kit] }
                   .custom_column(heading: 'Input Unit') { |op| op.temporary[:input_unit] }
                   .custom_column(heading: 'Output Unit') { |op| op.temporary[:output_unit] }
                   .custom_column(heading: 'Diluent A') { |op| op.ref('diluent A') }
                   .custom_column(heading: 'Input Ref') { |op| op.input_ref(INPUT) }
                   .custom_column(heading: 'Output Ref') { |op| op.output_ref(OUTPUT) }
                   .end_table
      end
    end
  end

  def centrifuge_samples(ops)
    labels = ops.map { |op| ref(op.output(OUTPUT).item) }
    diluentALabels = ops.map { |op| op.ref('diluent A') }
    show do
      title 'Centrifuge all samples for 5 seconds'
      check 'Place all tubes and samples in the centrifuge, along with a balancing tube. It is important to balance the tubes.'
      check 'Centrifuge the tubes for 5 seconds to pull down liquid and dried reagents'
    end
    # centrifuge_helper("sample", labels, CENTRIFUGE_TIME,
    #                   "to pull down dried powder.",
    #                   "There may be dried powder on the inside of the tube #{"lid".pluralize(labels.length)}.")
    # centrifuge_helper("tube", diluentALabels, CENTRIFUGE_TIME,
    #                   "to pull down liquid.")
  end

  def resuspend_pcr_mix(myops)
    gops = group_packages(myops)
    gops.each do |_unit, ops|
      from = ops.first.ref('diluent A')
      ops.each do |op|
        to_item = op.output(OUTPUT).item
        to = ref(to_item)
        tubeA = make_tube(opentube, [DILUENT_A, from], '', fluid = 'medium')
        tubeP = make_tube(opentube, [PCR_SAMPLE, to], '', fluid = 'powder').scale!(0.75)
        img = make_transfer(tubeA, tubeP, 300, "#{PCR_MIX_VOLUME}uL", "(#{P200_PRE} pipette)")
        img.translate!(25)
        show do
          raw transfer_title_proc(PCR_MIX_VOLUME, from, to)
          # title "Add #{PCR_MIX_VOLUME}uL from #{DILUENT_A} #{from.bold} to #{PCR_SAMPLE} #{to.bold}"
          note "#{DILUENT_A} will be used to dissolve the powder in the #{PCR_SAMPLE}."
          note "Use a #{P200_PRE} pipette and set it to <b>[0 4 0]</b>."
          note 'Avoid touching the inside of the lid, as this could cause contamination. '
          note 'Dispose of pipette tip.'
          check "Transfer #{PCR_MIX_VOLUME}uL from #{from.bold} into #{to.bold}"
          note display_svg(img, 0.75)
        end
      end

      # TODO: add "make sure tube caps are completely closed" for any centrifugation or vortexing step.
      #
    end

    labels = myops.map { |op| ref(op.output(OUTPUT).item) }
    vortex_and_centrifuge_helper('sample',
                                 labels,
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 'to mix.', 'to pull down liquid', AREA, mynote = nil)
  end

  def add_template_to_master_mix(myops)
    gops = group_packages(myops)

    gops.each do |_unit, ops|
      samples = ops.map { |op| op.input(INPUT).item }
      sample_refs = samples.map { |sample| ref(sample) }
      ops.each do |op|
        from = ref(op.input(INPUT).item)
        to = ref(op.output(OUTPUT).item)
        show do
          raw transfer_title_proc(SAMPLE_VOLUME, "#{SAMPLE_ALIAS} #{from}", "#{PCR_SAMPLE} #{to}")
          note "Carefully open tube #{from.bold} and tube #{to.bold}"
          note "Use a #{P20_PRE} pipette and set it to <b>[1 0 0]</b>."
          check "Transfer #{SAMPLE_VOLUME}uL from #{from.bold} into #{to.bold}"
          tubeS = make_tube(opentube, [SAMPLE_ALIAS, from], '', fluid = 'medium')
          tubeP = make_tube(opentube, [PCR_SAMPLE, to], '', fluid = 'medium').scale!(0.75)
          img = make_transfer(tubeS, tubeP, 300, "#{SAMPLE_VOLUME}uL", "(#{P20_PRE} pipette)")
          img.translate!(25)
          note display_svg(img, 0.75)
          check 'Close tubes and discard pipette tip'
        end
      end
    end
  end

  def start_thermocycler(ops)
    # Adds the PCR tubes to the PCR machine.
    # Instructions for PCR cycles.
    #
    samples = ops.map { |op| op.output(OUTPUT).item }
    sample_refs = samples.map { |sample| ref(sample) }

    # END OF PRE_PCR PROTOCOL

    vortex_and_centrifuge_helper(PCR_SAMPLE,
                                 sample_refs,
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 'to mix.', 'to pull down liquid', AREA, mynote = nil)

    t = Table.new
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
    t.add_column('STEP', ['Initial Melt', '45 cycles of', 'Extension', 'Hold'])
    t.add_column('TEMP', ['95C', cycles_temp, '72C', '4C'])
    t.add_column('TIME', ['4 min', cycles_time, '7 min', 'forever'])

    show do
      title 'Run PCR'
      check 'Talk to your assigner which thermocycler to use'
      check 'Close all the lids of the pipette tip boxes and pre-PCR rack'
      check "Take only the PCR tubes (#{sample_refs.to_sentence}) with you"
      check 'Place the PCR samples in the assigned thermocycler, close, and tighten the lid'
      check "Select the program named #{PCR_CYCLE} under OS"
      check "Hit #{'Run'.quote} and #{'OK to 50uL'.quote}"
      table t
    end

    operations.each do |op|
      op.output(OUTPUT).item.move THERMOCYCLER
    end

    # END OF POST_PCR PCR REACTION...
  end

  def cleanup(myops)
    items = [INPUT].map { |x| myops.map { |op| op.input(x) } }.flatten.uniq
    item_refs = [INPUT].map { |x| myops.map { |op| op.input_ref(x) } }.flatten.uniq
    temp_items = ['diluent A'].map { |x| myops.map { |op| op.ref(x) } }.flatten.uniq

    all_refs = temp_items + item_refs

    show do
      title "Discard items into the #{WASTE_PRE}"

      note "Discard the following items into the #{WASTE_PRE}"
      all_refs.each { |r| bullet r }
    end
    # clean_area AREA
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'You may start the next protocol in 2 hours.'
    end
  end
end # Class

```
