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
# Protocol to initiate an ola simple workflow. Meant to be executed without technician (can be run in debug mode)
# Performs all necessary setup to run the rest of the workflow.

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAKitIDs'
class Protocol
  include OLAConstants
  
  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'
  def main
    operations.make
    operations.each do |op|
      patient = op.input(PATIENT_ID_INPUT).value.to_i
      kit_id = op.input(KIT_ID_INPUT).value.to_i
      
      kit_operations = OLAKitIDs::get_kit_ops(kit_id, op.operation_type_id)
      
      OLAKitIDs::ensure_batch_size(kit_operations, kit_id)
      
      OLAKitIDs::assign_sample_aliases_from_kit_id(kit_operations, kit_id)
      
      data_assocations = []
      
      # assign/reassign the sample aliases for each workfow being run with this kit.
      kit_operations.each do |op|
        op.recurse_up  do |downstream_op|
          data_assocations << op.lazy_associate(SAMPLE_KEY, op.temporary[:sample_alias])
        end
      end
      
      # assign the patient id and kit id for all the ops in this workflow.
      op.output(OUTPUT).item.associate(PATIENT_ID_KEY, patient)
       op.recurse_up  do |downstream_op|
        data_assocations << downstream_op.associate(PATIENT_ID_KEY, patient)
        data_assocations << downstream_op.associate(KIT_KEY, kit_id)
      end
      
      # bulk import all of the created data associations.
      DataAssociation.import data_assocations, on_duplicate_key_update: [:object]
    end

    {}

  end
end

```
