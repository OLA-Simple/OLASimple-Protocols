# frozen_string_literal: true

needs 'OLASimple/OLAConstants'
module OLAKitIDs
  KIT_NUM_DIGITS = 3
  SAMPLE_NUM_DIGITS = 3
  BATCH_SIZE = OLAConstants::BATCH_SIZE
  PROPOGATION_KEYS = [OLAConstants::KIT_KEY, OLAConstants::SAMPLE_KEY, OLAConstants::PATIENT_KEY].freeze # which associations to propogate forward during an operation
  ALL_KIT_KEYS = PROPOGATION_KEYS + [OLAConstants::COMPONENT_KEY, OLAConstants::UNIT_KEY].freeze # all keys for important kit item associations

  def extract_kit_number(id)
    id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS].join.to_i if id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS]
  end

  def extract_sample_number(id)
    id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS].join.to_i if id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS]
  end

  def sample_num_to_id(num)
    num.to_s.rjust(SAMPLE_NUM_DIGITS, '0')
  end

  def kit_num_to_id(num)
    num.to_s.rjust(KIT_NUM_DIGITS, '0')
  end

  # requires and returns integer ids
  def kit_num_from_sample_num(sample_num)
    ((sample_num - 1) / BATCH_SIZE).floor + 1
  end

  # requires and returns integer ids
  def sample_nums_from_kit_num(kit_num)
    sample_nums = []
    BATCH_SIZE.times do |i|
      sample_nums << kit_num * BATCH_SIZE - i
    end
    sample_nums.reverse
  end

  def validate_samples(expected_sample_nums)
    resp = show do
      title 'Scan Incoming Samples'

      note 'Scan in the IDs of all incoming samples in any order.'
      note "There should not be more than #{expected_sample_nums.size} samples. "

      expected_sample_nums.size.times do |i|
        get 'text', var: i.to_s.to_sym, label: '', default: ''
      end
    end

    expected_sample_nums.size.times do |i|
      if extract_sample_number(resp[i.to_s.to_sym])
        found = expected_sample_nums.delete(extract_sample_number(resp[i.to_s.to_sym]))
      end
      return false unless found
    end
    true
  end

  def sample_validation_with_multiple_tries(kit_number)
    5.times do
      expected_sample_nums = sample_nums_from_kit_num(kit_number)
      expected_sample_nums = expected_sample_nums[0, operations.size]
      result = validate_samples(expected_sample_nums)
      return true if result || debug

      show do
        title 'Wrong Samples'
        note 'Ensure that you have the correct samples before continuing'
        note "You are processing kit <b>#{kit_num_to_id(kit_number)}</b>"
        note "Incoming samples should be numbered #{sample_nums_from_kit_num(kit_number).map { |s| sample_num_to_id(s) }.to_sentence}."
        note 'On the next step you will retry scanning in the samples.'
      end
    end
    operations.each do |op|
      op.error(:sample_problem, 'Incoming samples are wrong and could not be resolved')
    end
    raise 'Incoming samples are wrong and could not be resolved. Speak to a Lab manager.'
  end

  def record_technician_id
    resp = show do
      title 'Scan your technician ID'
      note 'Scan or write in the technician ID on your badge'
      get 'text', var: :id, label: 'ID', default: ''
    end
    operations.each do |op|
      op.associate(OLAConstants::TECH_KEY, resp[:id])
    end
  end

  ################################################################################
  ####  ID PROPOGATION
  ################################################################################

  def populate_temporary_kit_info_from_input_associations(ops, input_name)
    if debug
      ops.each_with_index do |op, i|
        op.temporary["input_#{OLAConstants::KIT_KEY}"] = kit_num_to_id(1)
        op.temporary["input_#{OLAConstants::SAMPLE_KEY}"] = sample_num_to_id(i + 1)
        op.temporary["input_#{OLAConstants::PATIENT_KEY}"] = rand(1..30).to_s
        op.temporary["output_#{OLAConstants::KIT_KEY}"] = op.temporary["input_#{OLAConstants::KIT_KEY}"]
        op.temporary["output_#{OLAConstants::SAMPLE_KEY}"] = op.temporary["input_#{OLAConstants::SAMPLE_KEY}"]
        op.temporary["output_#{OLAConstants::PATIENT_KEY}"] = op.temporary["input_#{OLAConstants::PATIENT_KEY}"]
      end
    else
      # grab all data associations from inputs and place into temporary
      populate_temporary_values_from_input_associations(ops, input_name, ALL_KIT_KEYS, PROPOGATION_KEYS)
    end
  end

  def populate_temporary_values_from_input_associations(ops, input_name, keys, propogated_keys)
    ops.each do |op|
      from = op.input(input_name).item
      from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
      from_das.each do |da|
        op.temporary["input_#{da.key}".to_sym] = da.value
        op.temporary["output_#{da.key}".to_sym] = da.value if PROPOGATION_KEYS.include?(da.key)
      end
    end
  end

  # Sends forward kit num, sample num, and patient id from the input item to the output item
  # for all operations
  def propogate_kit_info_forward(ops, input_name, output_name)
    das = []
    ops.each do |op|
      new_das = propogate_information_lazy(
        op.input(input_name).item,
        op.output(output_name).item,
        PROPOGATION_KEYS
      )
      das.concat(new_das)
    end
    DataAssociation.import das, on_duplicate_key_update: [:object]
  end

  # helper for propogate_kit_information_forward
  def propogate_information_lazy(from, to, keys = [])
    from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
    from_das.map { |da| to.lazy_associate(da.key, da.value) }
  end

  # Assumes only one output item
  # Sets the output items (and operation temporay values) to the given component and unit
  def set_output_components_and_units(ops, output_name, component, unit)
    data_associations = []
    ops.each do |op|
      it = op.output(output_name).item
      data_associations << it.lazy_associate(OLAConstants::COMPONENT_KEY, component)
      data_associations << it.lazy_associate(OLAConstants::UNIT_KEY, unit)
      op.temporary[OLAConstants::COMPONENT_KEY] = component
      op.temporary[OLAConstants::UNIT_KEY] = unit
    end
    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end
end
