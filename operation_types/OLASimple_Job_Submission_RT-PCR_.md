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
      kit_id = op.input(KIT_ID_INPUT).value.to_i
      # assign the patient id and kit id for all the ops in this workflow.
      op.associate(KIT_KEY, kit_id)
    end

    {}

  end
end

```
