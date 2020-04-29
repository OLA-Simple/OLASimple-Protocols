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
      op.output(OUTPUT).item.associate(PATIENT_ID_KEY, patient)
      op.output(OUTPUT).item.associate(KIT_KEY, kit_id)
      op.recurse_up  do |op|
        op.associate(PATIENT_ID_KEY, patient)
        op.associate(KIT_KEY, kit_id)
      end
    end

    {}

  end

end

```
