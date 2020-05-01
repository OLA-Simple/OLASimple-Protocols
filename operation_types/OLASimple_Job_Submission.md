# OLASimple Job Submission

Initializes an OLASimple workflow using the IDs of a whole blood sample and an OLASimple kit.


### Parameters

- **Patient Sample Identifier** 
- **Kit Identifier** 

### Outputs


- **Patient Sample** []  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Whole Blood")'>OLA Whole Blood</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# Protocol to initiate an ola simple workflow. Creates 

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
      
      ensure_batch_size(op, kit_id)
      
      op.output(OUTPUT).item.associate(PATIENT_ID_KEY, patient)
      op.output(OUTPUT).item.associate(KIT_KEY, kit_id)
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
  def ensure_batch_size(this_op, kit_id)
    last = Operation.last.id
    
    operations = Operation.where({ operation_type_id: this_op.operation_type_id, status: ["pending", "done"]}).last(100)
    operations = operations.to_a.uniq
    operations = operations.select { |op| op.get(KIT_KEY).to_i == kit_id.to_i }
    operations << this_op
    
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
end

```
