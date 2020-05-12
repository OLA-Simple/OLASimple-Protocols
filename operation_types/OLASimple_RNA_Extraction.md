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
##########################################
#
#
# OLASimple EasySep
# author: Abe Miller
# date: May 2020
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

  INPUT = "Plasma"
  OUTPUT = "Viral RNA"

  ##########################################
  # COMPONENTS
  ##########################################

  AREA = PRE_PCR
  BSC = "BSC"
  ETHANOL = "Ethanol"
  


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

  THIS_UNIT = PACK_HASH["Unit Name"]

  CENTRIFUGE_TIME = "1 minute"
  CENTRIFUGE_EXTRA_INSTRUCTIONS = "Discard flow through in GuSCN waste container"

  def main

    this_package = prepare_protocol_operations

    introduction
    safety_warning
    required_equipment
    retrieve_and_open_package(this_package)

    prepare_buffers
    lyse_samples
    add_ethanol

    3.times do
      operations.each { |op| add_sample_to_column(op) }
      centrifuge_columns
    end
    change_collection_tubes

    add_buffer_e2
    centrifuge_columns
    change_collection_tubes
    
    add_buffer_e3
    centrifuge_columns
    change_collection_tubes

    transfer_column_to_e6    
    elute
    incubate(sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }, "1 minute")
    centrifuge_columns

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

      note "In this protocol . "
      check "OLA RNA Extraction is highly sensitive. Small contamination can cause false positive. Before proceed, wipe the space and pipettes with 10% bleach and 70% ethanol."
      check "Put on tight gloves. Tight gloves help reduce contamination risk"
    end

  end

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
  
  def retrieve_and_open_package(this_package)
    show do
      title "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place on the #{BENCH_PRE} in the #{BSC}"
    end

    show do
      title "Open package #{this_package}"
      note "Arrange tubes on a plastic rack."
    end
  end
  
  # helper method for simple transfers in this protocol
  def transfer_and_vortex(title, from, to, volume)
    show do
      title title
      check "Transfer #{volume} of #{from} into #{to}."
      check 'Discard pipette tip.'
      check "Vortex #{to} for 2 seconds, twice."
    end
  end

  # helper method for simple incubations
  def incubate(samples, time)
    show do
      title 'Incubate Sample Solutions'
      note "Let #{samples.to_sentence} incubate for #{time} at room temperature."
      check "Set a timer for #{time}"
    end
  end

  def centrifuge_columns
    columns = sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}"}
    centrifuge_helper("Column", columns, CENTRIFUGE_TIME, "", AREA, CENTRIFUGE_EXTRA_INSTRUCTIONS)
  end
    
  def prepare_buffers
    # add sa water to dtt/trna
    show do
      title 'Prepare Buffers'
      note 'In the next few instructions, we will prepare the buffers used for the extraction.'      
      check "Transfer 25ul of #{SA_WATER} into #{DTT}."
      check 'Discard pipette tip.'
      check "Pulse vortex #{DTT}."
      check "Pulse centrifuge #{DTT}"
    end

    # add dtt solution to lysis buffer
    operations.each do |op|
      transfer_and_vortex(
        'Prepare Buffers', 
        DTT, 
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        '10uL'
      )
    end    

    # prepare wash buffer 2 with ethanaol
    transfer_and_vortex(
      'Prepare Buffers', 
      ETHANOL, 
      WASH2, 
      '1600uL'
    )
  end
  
  # transfer plasma Samples into lysis buffer and incubate
  def lyse_samples
    operations.each do |op|
      transfer_and_vortex(
        'Lyse Samples', 
        "#{INCOMING_SAMPLE_PREFIX}-#{op.temporary[:input_sample]}",
        "#{LYSIS_BUFFER}-#{op.temporary[:input_sample]}", 
        '380uL'
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
        '1900uL'
      )
    end
  end

  def add_sample_to_column(op)
    show do
      title 'Add Sample to Column'
      check "Carefully apply 630uL of #{LYSIS_BUFFER}-#{op.temporary[:input_sample]} onto the column #{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
    end
  end

  def change_collection_tubes
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do
      title 'Change Collection Tubes'
      sample_columns.each do |column|
        check "Transfer #{column} to new collection tube."
      end
      note "Discard previous collection tubes."
    end
  end

  def add_buffer_e2
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do 
      title "Add Buffer #{WASH1}"
      sample_columns.each do |column|
        note "Carefully open column #{column} lid."
        check "Add 500uL of buffer #{WASH1} to #{column}, and close the lid."
        check 'Discard pipette tip.'
      end
    end
  end

  def add_buffer_e3
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"}
    show do 
      title "Add Buffer #{WASH2}"
      sample_columns.each do |column|
        note "Carefully open column #{column} lid."
        check "Add 500uL of buffer #{WASH2} to #{column}, and close the lid."
        check 'Discard pipette tip.'
      end
    end
  end

  def transfer_column_to_e6
    show do
      title 'Transfer Columns'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:input_sample]}"
        check "Transfer #{column} to #{extract_tube}"
      end
    end
  end

  def elute
    show do 
      title 'Elute Columns'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        check "Add 60uL #{SA_WATER} to #{column}"
      end
    end
  end

  def finish_up
    show do
      title "Prepare Samples for Storage"
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:input_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:input_sample]}"
        check "Remove #{column} from #{extract_tube}, and discard #{column}"
      end
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}"}
      check "Place #{extract_tubes.to_sentence} on cold rack"
    end
  end

  def disinfect
    show do
      title 'Disinfect Items'
      check 'Spray and wipe down all reagents and samples with bleach and ethanol.'
    end
  end

  def cleanup
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
  end

  def store
    show do
      title 'Store Items'
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}"}
      note "Store #{extract_tubes.to_sentence} in -20C freezer"
    end
  end
end

```
