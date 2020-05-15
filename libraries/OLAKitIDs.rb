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
  
  def validate_samples(kit_number)
    expected_sample_nums = sample_nums_from_kit_num(kit_number)
    resp = show do
      title "Scan Incoming Samples"
      
      note "Scan in the ids of all incoming samples in any order."
      note "There should not be more than #{expected_sample_nums.size} samples. "
      
      expected_sample_nums.size.times do |i|
        get "text", var: i.to_s, label: "", default: ""
      end
    end
    
    expected_sample_nums.size.times do |i|
      if !resp[i.to_s].blank? && !expected_sample_nums.delete(extract_sample_number(resp[i.to_s]))
        return false
      end
    end
    return true
  end
  
  def sample_validation_with_multiple_tries(kit_number)
    5.times do
      result = validate_samples(kit_number)
      return true if result || debug
      show do
        title "Wrong Samples"
        note "Ensure that you have the correct samples before continuing"
        note "You are processing kit <b>#{kit_number}</b>"
        note "Incoming samples should be numbered #{sample_nums_from_kit_num(kit_number).to_sentence}."
        note "On the next step you will retry scanning in the samples."
      end
    end
    raise "Incoming samples are wrong and could not be resolved. Speak to a Lab manager."
  end
  
  # propogate kit id, sample alias, and original patient id (if available)
  # to the next item and operation
  def propogate_kit_information_to_next(op, input, output)
  end
  
  # Recurse up plan and apply kit information to all ops
  def propogate_kit_information_recursively(kit_id, sample_alias, patient_id)
  end
  
  # Apply kit information from op to output item
  def apply_kit_information_to_output(op, output) 
  end
end