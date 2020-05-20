needs 'OLASimple/OLAConstants'
module OLAKitIDs
  
  KIT_NUM_DIGITS = 3
  SAMPLE_NUM_DIGITS = 3
  BATCH_SIZE = OLAConstants::BATCH_SIZE
  
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
      op.associate(OLAConstants::TECH_ID, resp[:id])
    end
  end
  
  # propogate kit id, sample alias, and original patient id (if available)
  # to the next item and operation, from the specified input item
  def propogate_kit_information_to_next(op, input, output)
  end
  
  # Recurse up plan and apply kit information to all ops
  def propogate_kit_information_recursively(kit_id, sample_alias, patient_id)
  end
  
  # Apply kit information from op to output item
  def apply_kit_information_to_output(op, output) 
  end
end