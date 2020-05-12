# OLASimple Job Submission (RT-PCR)

Initializes an OLASimple workflow using the IDs of a whole blood sample and an OLASimple kit.


### Parameters

- **Patient Sample Identifier** 
- **Kit Identifier** 

### Outputs


- **Patient Sample** []  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA intention")'>OLA intention</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# Protocol to initiate an ola simple workflow. Not meant to be debugged. 

needs 'OLASimple/OLAConstants'
class Protocol
  include OLAConstants
  
  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'
  def main
    operations.make
    operations.each do |op|
      # give id to each blood sample 
      patient = op.input(PATIENT_ID_INPUT).value.to_i
      kit_id = op.input(KIT_ID_INPUT).value.to_i
      
      kit_operations = get_kit_ops(kit_id, op.operation_type_id)
      
      ensure_batch_size(op, kit_operations, kit_id)
      assign_sample_aliases_from_kit_id(kit_operations, kit_id)      
      
      op.output(OUTPUT).item.associate(PATIENT_ID_KEY, patient)
       op.recurse_up  do |op|
        op.associate(PATIENT_ID_KEY, patient)
        op.associate(KIT_KEY, kit_id)
      end
    end

    {}

  end
  
  # look through the last 100 ops of this operation type and ensure that 
  # there are not more than batch_size which share the same Kit
  # if there are, then error this operation 
  def ensure_batch_size(this_op, operations, kit_id)
    if operations.length > BATCH_SIZE
      operations.each do |op|
        op.error(:batch_too_big, "There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.")
        op.save
        op.plan.error("There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.", :batch_too_big)
        op.plan.save
      end
      if debug
        raise("There are too many samples being run with kit #{kit_id}. The Batch size is set to \"#{BATCH_SIZE}\", but there are #{operations.length} plans which list \"kit #{kit_id}\" as their kit association. All plans associated with kit #{kit_id} have been cancelled.")
      end
    end
  end
  
  # Assign sample aliases to items for all operations which share this kit
  # will be re-done every time a new job is submitted for this kit so that
  # the final sample id assignment is in correct sorted order when the next job is scheduled
  #
  # The sample alias in this case are found by splitting the kit id every 3 digits, other schemes can
  # be swapped in by changing "sample_aliases_from_kit"
  #
  # requires that "operations" input only contains operations from a single kit
  def assign_sample_aliases_from_kit_id(operations, kit_id)
    operations.each { |op| op.temporary[:patient] = op.get(PATIENT_ID_KEY) }
    operations = operations.sort { |op| op.temporary[:patient].to_i }
    sample_aliases = sample_aliases_from_kit(kit_id)
    operations.size.times do |i|
      operations[i].associate(SAMPLE_KEY, sample_aliases[i])
      operations[i].output(OUTPUT).item.associate(SAMPLE_KEY, sample_aliases[i])
    end
  end
  
  SAMPLE_ALIAS_DIGITS = 3
  def sample_aliases_from_kit(kit_id)
    kit_id.to_s.each_char.each_slice(SAMPLE_ALIAS_DIGITS).to_a.map { |a| a.join }.sort
  end
  
  # get list of operations with the given kit id
  # only retrieves operations which are done or running
  def get_kit_ops(kit_id, operation_type_id, lookback = 100)
    operations = Operation.where({ operation_type_id: operation_type_id, status: ["done", "running"]}).last(lookback)
    operations = operations.to_a.uniq
    operations = operations.select { |op| op.get(KIT_KEY).to_i == kit_id.to_i }
    operations # return
  end
end

```
