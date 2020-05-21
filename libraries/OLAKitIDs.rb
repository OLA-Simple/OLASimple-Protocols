needs 'OLASimple/OLAConstants'
module OLAKitIDs
  
  KIT_NUM_DIGITS = 3
  SAMPLE_NUM_DIGITS = 3
  BATCH_SIZE = OLAConstants::BATCH_SIZE
  PROPOGATION_KEYS = [OLAConstants::KIT_KEY, OLAConstants::SAMPLE_KEY, OLAConstants::PATIENT_KEY] #which associations to propogate forward during an operation
  
  def extract_kit_number(id)
    id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS].join.to_i
  end
  
  def extract_sample_number(id)
    id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS].join.to_i
  end
  
  def kit_num_from_sample_num(sample_num)
    ((sample_num - 1) / BATCH_SIZE).floor + 1
  end
  
  def sample_nums_from_kit_num(kit_num)
    sample_nums = []
    BATCH_SIZE.times do |i|
      sample_nums << kit_num * BATCH_SIZE - i
    end
    sample_nums.reverse
  end
  
  def validate_samples(expected_sample_nums)
    resp1 = show do
      title "Scan Incoming Samples"
      
      note "Scan in the IDs of all incoming samples in any order."
      note "There should not be more than #{expected_sample_nums.size} samples. "
      
      expected_sample_nums.size.times do |i|
        get "text", var: i.to_s, label: "", default: ""
      end
    end
    
    expected_sample_nums.size.times do |i|
      if !resp1[i.to_s].blank? && !expected_sample_nums.delete(extract_sample_number(resp1[i.to_s]))
        return false
      end
    end
    return true
  end
  
  def sample_validation_with_multiple_tries(kit_number)
    expected_sample_nums = sample_nums_from_kit_num(kit_number)
    expected_sample_nums = expected_sample_nums[0,operations.size]
    5.times do
      result = validate_samples(expected_sample_nums)
      return true if result || debug
      show do
        title "Wrong Samples"
        note "Ensure that you have the correct samples before continuing"
        note "You are processing kit <b>#{kit_number}</b>"
        note "Incoming samples should be numbered #{expected_sample_nums.to_sentence}."
        note "On the next step you will retry scanning in the samples."
      end
    end
    operations.each do |op|
      op.error(:sample_problem, 'Incoming samples are wrong and could not be resolved')
    end
    raise "Incoming samples are wrong and could not be resolved. Speak to a Lab manager."
  end
  
  def record_technician_id
    resp = show do
      title 'Scan your technician ID'
      note 'Scan or write in the technician ID on your badge'
      get "text", var: :id, label: 'ID', default: ""
    end
    operations.each do |op|
      op.associate(OLAConstants::TECH_KEY, resp[:id])
    end
  end
  
################################################################################
####  ID PROPOGATION
################################################################################

  def populate_temporary_kit_info_from_input_associations(ops, input_name)
    unless debug
      # grab all data associations from inputs and place into temporary
      populate_temporary_values_from_input_associations(ops, input_name, PROPOGATION_KEYS)
    else # debug mode
      ops.each_with_index do |op, i|
        op.temporary[OLAConstants::KIT_KEY] = 1.to_s.rjust(3, "0")
        op.temporary[OLAConstants::SAMPLE_KEY] = (i + 1).to_s.rjust(3, "0")
        op.temporary[OLAConstants::PATIENT_KEY] = rand(1..30)
      end
    end
  end

  def populate_temporary_values_from_input_associations(ops, input_name, keys)
    ops.each do |op|
      from = op.input(input_name).item
      from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
      from_das.each do |da|
        op.temporary[da.key.to_sym] = da.value
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
  
  # propogate all data associations included in keys from one object to another
  # returns data association list which much be imported in order to apply associations
  # as in `DataAssociation.import das, on_duplicate_key_update: [:object]`
  #
  # Does not work to propogate uploads currently
  def propogate_information_lazy(from, to, keys = [])
    from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
    from_das.map { |da| to.lazy_associate(da.key, da.value) }
  end
  
  def set_output_components(ops, component)
    set_many_associations(objects, COMPONENT_KEY, component)
  end
  
  def set_many_associations(objects, key, value, upload = nil)
    data_associations = []
    objects.each do |o|
      data_associations << o.lazy_associate(key, value, upload)
    end
    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end
  
################################################################################
####  WORKFLOW INITIATION
################################################################################

  # Assign sample aliases to items for all operations which share this kit
  # will be re-done every time a new job is submitted for this kit so that
  # the final sample id assignment is in correct sorted order when the next job is scheduled
  #
  # Assigns sample aliases in order of patient id. each operation must have op.temporary[:patient] set.
  # Sample alias assignment is placed in op.temporary[:sample_num] for each op.
  #
  # requires that "operations" input only contains operations from a single kit
  def assign_sample_aliases_from_kit_id(operations, kit_id)
    operations.each { |op| op.temporary[:patient] = op.get(OLAConstants::PATIENT_ID_KEY) }
    operations = operations.sort { |op| op.temporary[:patient] }
    sample_aliases = sample_aliases_from_kit(kit_id)
    operations.each_with_index do |op, i|
      op.temporary[:sample_num] = sample_alias[i]
    end
  end
  
  # get list of operations with the given kit id
  # only retrieves operations which are done or running
  # TODO speed up the data association queries
  def get_kit_ops(kit_id, operation_type_id, lookback = 100)
    operations = Operation.where({ operation_type_id: operation_type_id, status: ["done", "running"]}).last(lookback)
    operations = operations.to_a.uniq
    operations = operations.select { |op| op.get(OLAConstants::KIT_KEY).to_i == kit_id.to_i }
    operations # return
  end
  
  # must run DataAssociation.import on returned array in order to complete association
  def set_kit_information_lazy(obj, kit_num:, sample_num:, patient:)
    das = []
    das << obj.lazy_associate(OLAConstants::KIT_KEY, kit_num)
    das << obj.lazy_associate(OLAConstants::SAMPLE_KEY, sample_num)
    das << obj.lazy_associate(OLAConstants::PATIENT_KEY, patient)
  end
end