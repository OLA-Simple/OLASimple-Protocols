needs "OLASimple/OLAKits"

module OLAConstants
  include OLAKits

  ##########################################
  # DATA ASSOCIATION KEYS (DO NOT CHANGE)
  ##########################################
  #
  ALIAS_KEY = :alias
  KIT_KEY = :kit
  UNIT_KEY = :unit
  COMPONENT_KEY = :component
  SAMPLE_KEY = :sample
  SCANNED_IMAGE_UPLOAD_KEY = :scanned_image_upload
  SCANNED_IMAGE_UPLOAD_ID_KEY = :scanned_image_upload_id

  ##########################################
  # KIT SELECTION
  ##########################################

  KIT_SELECTION = OLAKits.uw_kit()
  KIT_NAME = KIT_SELECTION["name"]
  SAMPLE_PREP_UNIT = KIT_SELECTION["sample prep"]
  PCR_UNIT = KIT_SELECTION["pcr"]
  LIGATION_UNIT = KIT_SELECTION["ligation"]
  DETECTION_UNIT = KIT_SELECTION["detection"]
  ANALYSIS_UNIT = KIT_SELECTION["analysis"]
  COLORS = ANALYSIS_UNIT["Mutation Colors"]

  ##########################################
  # LAB SPECIFICATIONS
  ##########################################
  SAVE_SAMPLES = false
  SUPERVISOR = "Nuttada P. or Cami C."

  ##########################################
  # KIT SPECIFICATIONS
  ##########################################

  # mutations
  MUTATIONKEY = :mutations

  # kit components
  DILUENT_A = "Diluent A" # what to call the Diluent A tube (i.e. water)
  STOP_MIX = "stop mix" # what to call the input samples (cell lysates)
  GOLD_MIX = "gold mix"
  STRIP = "detection strip"
  STRIPS = STRIP.pluralize(10)
  BAND = "band"
  BANDS = "bands"
  PANEL = "panel"
  AQUARIUM = "Aquarium"

  ##########################################
  # CODONS
  ##########################################

  pcr_pkg_color = "STEELBLUE"
  lig_pkg_color = "PALETURQUOISE"
  det_pkg_color = "MEDIUMPURPLE"
  SAMPLE_PREP_PKG_NAME = "sample prep package"
  PCR_PKG_NAME = "PCR package"
  LIG_PKG_NAME = "ligation package"
  DET_PKG_NAME = "detection package"

  # names of sample field value and validate kit field types
  SAMPLE_PREP_FIELD_VALUE = "Sample Prep Pack"
  PCR_FIELD_VALUE = "PCR Pack"
  LIGATION_FIELD_VALUE = "Ligation Pack"
  DETECTION_FIELD_VALUE = "Detection Pack"
  KIT_FIELD_VALUE = "Kit"
  CODONS_FIELD_VALUE = "Codons"
  CODON_COLORS_FIELD_VALUE = "Codon Colors"
  NUM_SAMPLES_FIELD_VALUE = "Number of Samples"
  NUM_SUB_PACKAGES_FIELD_VALUE = "Number of Sub Packages"
  UNIT_NAME_FIELD_VALUE = "Unit Name"
  COMPONENTS_FIELD_VALUE = "Components"

  ##########################################
  # TERMINOLOGY
  ##########################################

  # kit samples
  CELL_LYSATE = "cell lysate" # what to call the input samples (cell lysates)
  PCR_SAMPLE = "PCR sample" # what to call the tubes for the PCR protocol
  LIGATION_SAMPLE = "ligation sample"

  # equipment
  THERMOCYCLER = "thermocycler" # what to call the thermocycler
  CENTRIFUGE = "centrifuge"
  PCR_RACK = "PCR rack" # what to call the racks the PCR tubes go in
  PHOTOCOPIER = "scanner"
  BASIC_MATERIALS = [
      "200uL pipette and filtered tips",
      "20uL pipette and filtered tips",
      "a spray bottle of 10% v/v bleach",
      "a spray bottle of 70% v/v ethanol",
      "a timer",
      "latex gloves"
  ]
  TRASH = "trash"
  WASTE = "biohazard waste (red bag)" # what to call the biohazard waste
  BENCH = "bench"
  PACKAGE = "package"
  FRIDGE = "fridge"
  P20 = "P20"
  P200 = "P200"
  P1000 = "P1000"
  WIPE = "KimWipe"

  # verbs
  CENTRIFUGE_VERB = "centrifuge" # or spin?

  # areas
  PRE_PCR = "pre-PCR"
  POST_PCR = "post-PCR"

  PCR_CYCLE = "OSPCR"
  LIG_CYCLE = "OSLIG"
  STOP_CYCLE = "OSSTOP"

  def map_temporary_from_input(input, outputs, keys)
    outputs = [outputs].flatten
    keys = [keys].flatten
    operations.each do |op|
      input_item = op.input(input).item
      outputs.each do |out|
        keys.each do |k|
          op.output(out).item.associate LOT, input_item.get(k)
        end
      end
    end
  end

  def explicit_retrieve
    operations.retrieve interactive: false

    show do
      title "Retrieve the following items:"

      t = Table.new
      input_items = operations.map {|op| op.inputs.map {|i| i.item}}.flatten
      t.add_column("ID", input_items.map {|i| i.id})
      t.add_column("Type", input_items.map {|i| i.object_type.name})
      t.add_column("Location", input_items.map {|i| i.location})
      table t
    end
  end
end
