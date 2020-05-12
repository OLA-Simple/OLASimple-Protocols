needs OLAConstants
module OLAKitBarcodes
  
  KIT_NUM_DIGITS = 3
  SAMPLE_NUM_DIGITS = 3
  BATCH_SIZE = OLAConstants::BATCH_SIZE
  
  def extract_kit_number(id)
    id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS].join
  end
  
  def extract_sample_number(id)
    id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS].join
  end
  
  def kit_num_from_sample_num(sample_num)
    ((sample_num - 1) / BATCH_SIZE).floor + 1
  end
  
  def sample_nums_from_kit_num(kit_num)
    sample_nums = []
    BATCH_SIZE.times do |i|
      sample_nums << kit_num * BATCH_SIZE - i
    end
    sample_nums
  end
  
  def validate_samples(kit_number, sample_prefix)
    # TODO
    show do
    end
  end
end