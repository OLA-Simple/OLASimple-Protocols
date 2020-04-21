# Library code here
# category = "Tissue Culture Libs"
# needs "#{category}/TissueCulture"
needs "OLASimple/OLAConstants"
needs "OLASimple/OLAGraphics"
needs "OLASimple/NetworkRequests"

module TextExtension
  include ActionView::Helpers::TagHelper

  def bold
    return content_tag(:b, "#{self}")
  end

  def ital
    return content_tag(:i, "#{self}")
  end

  def strong
    return content_tag(:strong, "#{self}")
  end

  def color(which_color)
    return content_tag(:font, "#{self}", color: which_color)
  end

  def cap
    remaining = ""
    remaining = self[1..-1] if self.length > 1
    return self[0].capitalize + remaining
  end

  def quote
    return "\"#{self}\""
  end
end

module RefExtension
  include OLAConstants
  # this requires :output_kit, :output_unit, :output_sample, and :pack_hash temporary values
  # references require :kit, :unit, :component, and :sample keys

  def sort_by &block
    super(&block).extend(OperationList)
  end

  def component(name)
    self.temporary[:pack_hash][COMPONENTS_FIELD_VALUE][name]
  end

  def input_component(name)
    get_input_item_helper(name).get(COMPONENT_KEY)
  end

  def output_component(name)
    self.get_output_item_helper(name).get(COMPONENT_KEY)
  end

  def ref(name, with_sample = false)
    # returns the label for a temporary item by name
    t = self.temporary
    c = self.component(name)
    kit = t[:output_kit]
    unit = t[:output_unit]
    # samp = t[:output_sample]
    samp = ""
    if with_sample
      samp = t[:output_sample]
    end
    self.alias_helper(kit, unit, c, samp)
  end

  def tube_label(name, with_sample = false)
    self.label_helper(*self.ref_tokens(name, with_sample))
  end

  def label_helper(k, u, c, s)
    ["#{k}#{u}", "#{c}#{s}"]
  end

  def input_tube_label(name)
    self.label_helper(*self.input_tokens(name))
  end

  def output_tube_label(name)
    self.label_helper(*self.output_tokens(name))
  end

  # TOKENS
  def ref_tokens(name, with_sample = false)
    # return array for kit-unit and component-sample, usually for labeling purposes
    t = self.temporary
    c = self.component(name)
    kit = t[:output_kit]
    unit = t[:output_unit]
    samp = "" #t[:output_sample]
    if with_sample
      samp = t[:output_sample]
    end
    [kit, unit, c, samp]
  end

  def ref_tokens_helper(item)
    [item.get(KIT_KEY), item.get(UNIT_KEY), item.get(COMPONENT_KEY), item.get(SAMPLE_KEY)]
  end

  def input_tokens(name)
    self.ref_tokens_helper(self.get_input_item_helper(name))
  end

  def output_tokens(name)
    self.ref_tokens_helper(self.get_output_item_helper(name))
  end

  def alias_helper(kit, unit, component, sample)
    # returns the label given kit, unit, comp and sample
    "#{kit}#{unit}#{component}#{sample}"
  end

  def ref_helper(item)
    # returns the label for an item
    self.alias_helper(*self.ref_tokens_helper(item))
  end

  def refs_helper(item)
    # returns an array of labels for a collection
    components = item.get(COMPONENT_KEY)
    raise "Components must be an array to use refs_helper" unless components.is_a?(Array)
    components.map do |c|
      self.alias_helper(item.get(KIT_KEY), item.get(UNIT_KEY), c, item.get(SAMPLE_KEY))
    end
  end

  def get_input_item_helper(name)
    input = self.input(name)
    raise "Could not find input field_value #{name}" if input.nil?
    item = input(name).item
    raise "Input #{name} has no item" if item.nil?
    item
  end

  def get_output_item_helper(name)
    output = self.output(name)
    raise "Could not find output field_value \"#{name}\"" if output.nil?
    item = output(name).item
    raise "Output \"#{name}\" has no item" if item.nil?
    item
  end

  def input_ref(name)
    # return the label for an input
    self.ref_helper(get_input_item_helper(name))
  end

  def input_ref_tokens(name)
    # return the label for an input
    self.ref_tokens_helper(get_input_item_helper(name))
  end

  def output_ref(name)
    # return the label for an output
    self.ref_helper(get_output_item_helper(name))
  end

  def output_ref_tokens(name)
    # return the label for an input
    self.ref_tokens_helper(get_output_item_helper(name))
  end

  def input_refs(name)
    # return the array of labels for an input
    self.refs_helper(get_input_item_helper(name))
  end

  def output_refs(name)
    # return the array of labels for an output
    self.refs_helper(get_output_item_helper(name))
  end

  def make_alias_from_pack_hash(output_item, package_name, from_item)
    kit = self.temporary[:output_kit]
    unit = self.temporary[:output_unit]
    component = self.component(package_name)
    sample = self.temporary[:output_sample]
    patient = self.temporary[:patient]

    raise "Kit is nil" if kit.nil?
    raise "Unit is nil" if unit.nil?
    raise "Component is nil" if component.nil?
    raise "Sample is nil" if sample.nil?
    raise "Patient ID is nil" if sample.nil?

    output_item.associate(KIT_KEY, kit)
    output_item.associate(UNIT_KEY, unit)
    output_item.associate(COMPONENT_KEY, component)
    output_item.associate(SAMPLE_KEY, sample)
    output_item.associate(PATIENT_ID_KEY, patient)
    output_item.associate(ALIAS_KEY, self.ref_helper(output_item))

    # from associations
    output_item.associate(:from, self.input(from_item).item.id)
    output_item.associate(:fromref, self.input_ref(from_item))
    output_item.associate(:from_pack, "#{self.temporary[:input_kit]}#{self.temporary[:input_unit]}")
    output_item
  end

  def make_item_and_alias(name, package_name, from_item)
    output_item = self.output(name).make
    self.make_alias_from_pack_hash(output_item, package_name, from_item)
  end

  def make_collection_and_alias(name, package_name, from_item)
    output_collection = self.output(name).make_collection
    components = self.component(package_name)
    components.each do |c|
      output_collection.add_one(self.output(name).sample)
    end
    output_item = self.output(name).item
    self.make_alias_from_pack_hash(output_item, package_name, from_item)
  end
end

module OLALib
  include OLAConstants
  include NetworkRequests

  String.send(:prepend, TextExtension)
  Integer.send(:prepend, TextExtension)
  Float.send(:prepend, TextExtension)
  Operation.send(:prepend, RefExtension)
#   include TissueCulture

#######################################
# OLA image processing API
#######################################

  # TODO add error handling to this function, since function could fail if api service disconnected
  def make_calls_from_image(image_upload)
    res = post_file(OLA_IP_API_URL, 'file', image_upload)
    return JSON.parse(res.body)['results']
  end

#######################################
# Utilities
#######################################

  def pluralizer(noun, num)
    if num == 1
      "the #{noun.pluralize(num)}"
    elsif num == 2
      "both #{noun.pluralize(num)}"
    else
      "all #{num} #{noun.pluralize(num)}"
    end
  end

  def group_by_unit ops
    ops.running.group_by {|op| op.temporary[:unit]}
  end

  def get_technician_name(job_id)
    job = Job.find(job_id)
    user_id = job.user_id
    username = "\"unknown user\""
    unless user_id.nil?
      username = User.find(job.user_id).name
    end
    username
  end

####################################
# Item Alias
####################################

  def alias_helper(kit, unit, component, sample = nil)
    sample = sample || ""
    "#{kit}#{unit}#{component}#{sample}"
  end

  def make_alias(item, kit, unit, component, sample = nil)
    sample = sample || ""
    label = alias_helper(kit, unit, component, sample)
    item.associate(ALIAS_KEY, label)
    item.associate(KIT_KEY, kit)
    item.associate(UNIT_KEY, unit)
    item.associate(COMPONENT_KEY, component)
    item.associate(SAMPLE_KEY, sample)
  end

  def get_alias_array(item)
    [item.get(KIT_KEY), item.get(UNIT_KEY), item.get(COMPONENT_KEY), item.get(SAMPLE_KEY), item.get(PATIENT_ID_KEY)]
  end

  def ref(item)
    "#{item.get(KIT_KEY)}#{item.get(UNIT_KEY)}#{item.get(COMPONENT_KEY)}#{item.get(SAMPLE_KEY)}"
  end

  def save_temporary_input_values(ops, input)
    # get the aliases from the inputs
    ops.each do |op|
      kit, unit, component, sample, patient = get_alias_array(op.input(input).item)
      op.temporary[:patient] = patient
      op.temporary[:input_kit] = kit
      op.temporary[:input_unit] = unit
      op.temporary[:input_component] = component
      op.temporary[:input_sample] = sample
      op.temporary[:input_kit_and_unit] = [kit, unit].join('')
    end
  end

  def save_pack_hash(ops, pack)
    ops.running.each do |op|
      op.temporary[:pack_hash] = get_pack_hash(op.input(pack).sample)
    end
  end

  def save_temporary_output_values(myops)
    myops.each do |op|
      op.temporary[:output_kit] = op.temporary[:input_kit]
      op.temporary[:output_unit] = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
      op.temporary[:output_sample] = op.temporary[:input_sample]
      op.temporary[:output_kit_and_unit] = [op.temporary[:output_kit], op.temporary[:output_unit]].join('')
      op.temporary[:output_number_of_samples] = op.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
    end
  end

#   def save_temporary_output_values(myops, pack_field_value_name, unit)
#     myops.each do |op|
#       op.temporary[:output_kit] = op.temporary[:input_kit]
#       op.temporary[:output_sample] = op.temporary[:input_sample]
#       op.temporary[:output_unit] = unit
#       op.temporary[:output_kit_and_unit] = [op.temporary[:output_kit], op.temporary[:output_unit]].join('')
#     end
#   end

  def group_packages(myops)
    myops.group_by {|op| op.temporary[:output_kit_and_unit]}
  end


####################################
# Collection Alias
####################################

  def make_array_association(item, label, data)
    raise "must be an item not a collection for array associations" unless item.is_a?(Item)
    data.each.with_index do |d, i|
      item.associate("#{label}#{i}".to_sym, d)
    end
  end

  def get_array_association(item, label, i)
    item.get("#{label}#{i}".to_sym)
  end

  def make_collection_alias(item, kit, unit, components, sample = nil)
    sample = sample || ""
    raise "must be an item not a collection for array associations" unless item.is_a?(Item)
    item.associate(KIT_KEY, kit)
    item.associate(UNIT_KEY, unit)
    make_array_association(item, COMPONENT_KEY, components)
    item.associate(SAMPLE_KEY, sample)
  end

  def collection_ref(collection, index)
    component = get_array_association(collection, COMPONENT_KEY, index)
    "#{collection.get(KIT_KEY)}#{collection.get(UNIT_KEY)}#{component}#{collection.get(SAMPLE_KEY)}"
  end

  def get_collection_refs(item, length)
    length.times.map do |i|
      collection_ref(item, i)
    end
  end

####################################
# Kit and Package Parser
####################################

  def parse_component(component_string)
    # parses the component value for a OLASimple Package sample
    # values are formatted as "key: value" or "key: [val1, val2, val3]"
    val = nil
    tokens = component_string.split(/\s*\:\s*/)
    m = /\[(.+)\]/.match(tokens[1])
    if not m.nil?
      arr_str = m[1]
      val = arr_str.split(/\s*,\s*/).map {|x| x.strip()}
    else
      val = tokens[1]
    end
    return tokens[0], val
  end

  def get_component_dictionary(package_sample)
    # parses all of the components in a OLASimple Package
    components = package_sample.properties[COMPONENTS_FIELD_VALUE]
    components.map {|v| [*parse_component(v)]}.to_h
  end


  def get_pack_hash(sample)
    pack_hash = {}
    # get the properties for the output pack sample
    pack_hash = sample.properties

    # parse the component values, formatted as "key: value" or "key: [val1, val2, val3]"
    pack_hash[COMPONENTS_FIELD_VALUE] = get_component_dictionary(sample)
    pack_hash
  end

  def get_kit_hash(op)
    kit_hash = {}
    # validates that input and output kits sample definitions are formatted correctly
    [SAMPLE_PREP_FIELD_VALUE, PCR_FIELD_VALUE, LIGATION_FIELD_VALUE, DETECTION_FIELD_VALUE].each do |x|
      # validate that the input kit is the same as the expected output kits
      output_sample = op.output(x).sample
      kit_hash[x] = get_pack_hash(output_sample)
    end

    kit_hash
  end

  def kit_hash_to_json(kit_hash)
    h = kit_hash.map {|k, v| [k, v.reject {|key, val| key == KIT_FIELD_VALUE}]}.to_h
    JSON.pretty_generate(h)
  end

  def validate_kit_hash(op, kit_hash)
    # validates the kit hash
    errors = []


    kit_hash.each do |pack_name, pack_properties|
      if pack_properties.empty?
        errors.push(["components_empty_for_#{pack_name}".to_sym, "Package components are empty!"])
      end

      if pack_properties[KIT_FIELD_VALUE] != op.input(KIT_FIELD_VALUE).sample
        errors.push(["kit_not_found_in_input_for_#{pack_name}".to_sym, "Input kit does not match output package definition."])
      end
    end

    kit_sample = op.input(KIT_FIELD_VALUE).sample
    kit_sample_props = kit_sample.properties
    num_codons = kit_sample_props[CODONS_FIELD_VALUE].length
    num_codon_colors = kit_sample_props[CODON_COLORS_FIELD_VALUE].length
    num_ligation_tubes = kit_hash[LIGATION_FIELD_VALUE][COMPONENTS_FIELD_VALUE]["sample tubes"].length
    num_strips = kit_hash[DETECTION_FIELD_VALUE][COMPONENTS_FIELD_VALUE]["strips"].length

    if debug
      show do
        title "DEBUG: Kit Hash Errors"
        errors.each do |k, v|
          note "#{k}: #{v}"
        end
      end
    end

    errors.each do |k, v|
      op.error(k, v)
    end

    if debug
      show do
        title "DEBUG: Kit Hash"
        note "#{kit_hash_to_json(kit_hash)}"
        # note "#{kit_hash}"
      end
    end
  end

####################################
# Step Utilities
####################################

  def check_for_tube_defects myops
    # show do
    defects = show do
      title "Check for cracked or damaged tubes."
      select ["No", "Yes"], var: "cracked", label: "If there are cracks or defects in the tube, select \"Yes\" from the dropdown menu below.", default: 0
      note "If yes, #{SUPERVISOR} will replace the samples or tubes for you."
    end

    if defects["cracked"] == "Yes"
      show do
        title "Contact #{SUPERVISOR} about missing or damaged tubes."

        note "You said there are some problems with the samples."
        check "Contact #{SUPERVISOR} about this issue."
        note "We will simply replace these samples for you."
      end
    end
  end

  def area_preparation which_area, materials, other_area
    show do
     title "Put on a pair of gloves"
    end

    show do
      title "#{which_area.cap} preparation"

      note "You will be doing the protocol in the #{which_area.bold} area"
      warning "Put on a pair of gloves now"
      warning "Keep all materials in the #{which_area.bold} area separate from the #{other_area.bold} area"
      note "Before continuing, make sure you have the following items in the #{which_area.bold} area:"
      materials.each do |i|
        check i
      end
    end
  end

  def put_on_ppe which_area
    show do
      title "Put on Lab Coat and Gloves"

      check "Put on a lab coat"
      warning "make sure lab coat is from the #{which_area.bold}"
      check "Put on a pair of latex gloves."
    end
  end

  def transfer_title_proc(vol, from, to)
    p = Proc.new {
      title "Add #{vol}uL from #{from.bold} to #{to.bold}"
    }
    ShowBlock.new(self).run(&p)
  end

  def show_open_package(kit, unit, num_sub_packages)
    show do
      title "Tear open #{kit.bold}#{unit.bold}"
      if num_sub_packages > 0
        note "Tear open all smaller packages."
      end
      self.run(&Proc.new) if block_given?
      check "Discard the packaging material in the paper box on your right."
    end
  end

  def centrifuge_proc(sample_identifier, sample_labels, time, reason, area, balance = false)
    if area == PRE_PCR
        centrifuge = CENTRIFUGE_PRE
    elsif area == POST_PCR
        centrifuge = CENTRIFUGE_POST
    else
        raise "Invalid Area"
    end
    p = Proc.new {
      check "Place #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.join(', ').bold} in the #{centrifuge}"
      check "#{CENTRIFUGE_VERB.cap} #{pluralizer(sample_identifier, sample_labels.length)} for #{time} #{reason}"
      if balance
        if num.even?
          warning "Balance tubes in the #{centrifuge} by placing #{num / 2} #{sample_identifier.pluralize(num / 2)} on each side."
        else
          warning "Use a spare tube to balance #{sample_identifier.pluralize(num)}."
        end
      end
    }
    ShowBlock.new(self).run(&p)
  end

  def vortex_proc(sample_identifier, sample_labels, time, reason)
    p = Proc.new {
      # check "Vortex #{pluralizer(sample_identifier, num)} for #{time} #{reason}"
      check "Vortex #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.join(', ').bold} for #{time} #{reason}"
      # check "Vortex #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.map { |label| label.bold })}
    }
    ShowBlock.new(self).run(&p)
  end

  def centrifuge_helper(sample_identifier, sample_labels, time, reason, area, mynote = nil)
    sample_labels = sample_labels.uniq
    show do
      title "#{CENTRIFUGE_VERB.cap} #{sample_identifier.pluralize(sample_labels.length)} for #{time}"
      if not mynote.nil?
        note mynote
      end
      warning "Close #{pluralizer("tube cap", sample_labels.length)}."
      raw centrifuge_proc(sample_identifier, sample_labels, time, reason, area)
    end
  end

  def vortex_helper(sample_identifier,
                    sample_labels,
                    vortex_time,
                    vortex_reason, mynote = nil)
    num = sample_labels.length
    show do
      title "Vortex #{sample_identifier.pluralize(num)}"
      if not mynote.nil?
        note mynote
      end
      warning "Close #{pluralizer("tube cap", sample_labels.length)}."
      raw vortex_proc(sample_identifier, sample_labels, vortex_time, vortex_reason)
    end
  end

  def vortex_and_centrifuge_helper(sample_identifier,
                                   sample_labels,
                                   vortex_time, spin_time,
                                   vortex_reason, spin_reason, area, mynote = nil)
    num = sample_labels.length
    show do
      title "Vortex and #{CENTRIFUGE_VERB} #{sample_identifier.pluralize(num)}"
      if not mynote.nil?
        note mynote
      end
      warning "Close #{pluralizer("tube cap", sample_labels.length)}."
      # note "Using #{sample_identifier.pluralize(num)} #{sample_labels.join(', ').bold}:"
      raw vortex_proc(sample_identifier, sample_labels, vortex_time, vortex_reason)
      raw centrifuge_proc(sample_identifier, sample_labels, spin_time, spin_reason, area)
      check "Place the tubes back on rack"
    end
  end

  def add_to_thermocycler(sample_identifier, sample_labels, program_name, program_table, name)
    if sample_labels.is_a?(Array)
      len = sample_labels.length
    else
      len = sample_labels
    end

    show do
      title "Run #{name}"
      check "Add #{pluralizer(sample_identifier, len)} to #{THERMOCYCLER}"
      check "Close and tighten the lid."
      check "Select the program named #{program_name.bold} under the <b>OS</b>"
      check "Hit <b>\"Run\"</b> and click <b>\"OK\"</b>"
      table program_table
    end
  end

  def clean_area which_area
    show do
      disinfectant = "10% bleach"
      title "Wipe down #{which_area.bold} with #{disinfectant.bold}."
      note "Now you will wipe down your #{BENCH} and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray a small amount of #{disinfectant.bold} on the bench surface. Clean bench with #{WIPE}."
      # check "Spray some #{disinfectant.bold} on a #{WIPE}, gently wipe down keyboard and mouse of this computer/tablet."
      warning "Do not spray #{disinfectant.bold} onto tablet or computer!"
      check "Finally, spray outside of gloves with #{disinfectant.bold}."
    end

    show do
      disinfectant = "70% ethanol"
      title "Wipe down #{which_area.bold} with #{disinfectant.bold}."
      note "Now you will wipe down your #{BENCH} and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray a small amount of #{disinfectant.bold} on the bench surface. Clean bench with #{WIPE}."
      #   check "Spray a #{"small".bold} amount of #{disinfectant.bold} on a #{WIPE}. Gently wipe down keyboard and mouse of this computer/tablet."
      warning "Do not spray #{disinfectant.bold} onto tablet or computer!"
      check "Finally, spray outside of gloves with #{disinfectant.bold}."
    end
  end

  def area_setup area, materials, other_area = nil
    area_preparation area, materials, other_area
    put_on_ppe area
    clean_area area
  end


####################################
# Displaying Images
######################################
  def extract_basename filename
    ext = File.extname(filename)
    basename = File.basename(filename, ext)
    basename
  end

  def show_with_expected_uploads(op, filename, save_key = nil, num_tries = 5)
    upload_hashes = []
    warning_msg = nil
    num_tries.times.each do |i|
      if upload_hashes.empty?
        # ask for uploads
        result = show do
          warning warning_msg unless warning_msg.nil?
          self.run(&Proc.new) if block_given?
          upload var: :files
        end
        upload_hashes = result[:files] || []

        if debug and i >= 1
          n = "default_filename.txt"
          if i >= 2
            n = filename
          end
          upload_hashes.push({:id => 12345, :name => n})
        end

        # try again if not files were uploaded
        if upload_hashes.empty?
          warning_msg = "You did not upload any files! Please try again."
        end

        unless upload_hashes.empty?
          # get name to id hash
          name_to_id_hash = upload_hashes.map {|u| [extract_basename(u[:name]), u[:id]]}.to_h

          # get the file even if technician uploaded multiple files
          if name_to_id_hash.keys.include?(extract_basename(filename))
            upload_hashes = [{name: filename, id: name_to_id_hash[filename]}]
          else
            warning_msg = "File #{filename} not uploaded. Please find file <b>\"#{filename}\"</b>. You uploaded files #{name_to_id_hash.keys.join(', ')}"
            upload_hashes = []
          end
        end
      end
    end
    raise "Expected file uploads, but there were none!" if upload_hashes.empty?

    upload_ids = upload_hashes.map {|uhash| uhash[:id]}
    uploads = []
    if debug
      random_uploads = Upload.includes(:job)
      uploads = upload_ids.map {|u| random_uploads.sample}
    else
      uploads = upload_ids.map {|u_id| Upload.find(u_id)}
    end
    upload = uploads.first
    op.temporary[save_key] = upload unless save_key.nil?
    op.temporary["#{save_key}_id".to_sym] = upload.id unless save_key.nil?
    return upload
  end

  def display_upload(upload, size = "100%")
    p = Proc.new do
      note "<img src=\"#{upload.expiring_url}\" width=\"#{size}\"></img>"
    end
    ShowBlock.new(self).run(&p)
  end

    def display_strip_section(upload, display_section, num_sections, size)
      p = Proc.new do
          x = 100.0/num_sections
          styles = []
          num_sections.times.each do |section|
              x1 = 100 - (x * (section+1)).to_i
              x2 = (x*(section)).to_i
              styles.push(".clipimg#{section} { clip-path: inset(0% #{x1}% 0% #{x2}%); }")
          end
          style = "<head><style>#{styles.join(' ')}</style></head>"
          note style
          note "<img class=\"clipimg#{display_section}\" src=\"#{upload.expiring_url}\" width=\"#{size}\"></img>" 
      end
      ShowBlock.new(self).run(&p)
  end

end