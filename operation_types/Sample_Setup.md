# Sample Setup

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.


### Parameters

- **Kit Number** 

### Outputs


- **Whole Blood A** [A]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Whole Blood")'>OLA Whole Blood</a>

- **Whole Blood B** [B]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLA Whole Blood")'>OLA Whole Blood</a>

- **Synthetic Sample A** [A]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLASimple Synthetic DNA")'>OLASimple Synthetic DNA</a>

- **Synthetic Sample B** [B]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLASimple Synthetic DNA")'>OLASimple Synthetic DNA</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
##########################################
#
#
# Make fake lysed blood sample
# author: Justin Vrana
# date: March 2018
#
#
##########################################

# NOTES FROM DAY 1:
# "add" >> "place" for placing things in places
# add steps for doing things while you wait for the magnetic rack
# specify when you can continue for timed steps
# try to add the javascript step 
# for removing supernatent (slide 40)
     # "carefully remove the supernatent while trying not to disturb the cell pellet"
     # set pipette to 900uL
     # display picture of cells and pellet and trying to avoid cell pellet
# removal of supernatent needs to be more detailed
# fonts need to be bigger for ALL slides
# reinstate checkboxes? Use foot pedal by hand to progress?
# label separations by first, second, third separation
# put AB1 (RBC Lysis Buffer), put reagent in brackets
needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics

  KIT_NUM = "Kit Number"
  BLOOD_A = "Whole Blood A"
  BLOOD_B = "Whole Blood B"
  DNA_A = "Synthetic Sample A"
  DNA_B = "Synthetic Sample B"
  
  def main
    
    operations.running.retrieve interactive: false
    
    operations.running.each do |op|
        op.temporary[:output_kit] = op.input(KIT_NUM).val.to_s
    end
    
    
    
    operations.running.each do |op|
        op.temporary[:pack_hash] = SAMPLE_PREP_UNIT
        op.temporary[:output_unit] = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
        op.temporary[:output_sample] = op.temporary[:input_sample]
        # op.temporary[:output_kit_and_unit] = [op.temporary[:output_kit], op.temporary[:output_unit]].join('')
        # op.temporary[:output_number_of_samples] = op.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        
        kit = op.temporary[:output_kit]
        unit = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
        component = op.component("sample tube 4")
        # sample = self.temporary[:output_sample]
        sample = 1
    
        raise "Kit is nil" if kit.nil?
        raise "Unit is nil" if unit.nil?
        raise "Component is nil" if component.nil?
        raise "Sample is nil" if sample.nil?
        output_item_a = op.output(DNA_A).make
        output_item_a.associate(KIT_KEY, kit)
        output_item_a.associate(UNIT_KEY, unit)
        output_item_a.associate(COMPONENT_KEY, component)
        output_item_a.associate(SAMPLE_KEY, 1)
        output_item_a.associate(ALIAS_KEY, op.ref_helper(output_item_a))
        
        output_item_b = op.output(DNA_B).make
        output_item_b.associate(KIT_KEY, kit)
        output_item_b.associate(UNIT_KEY, unit)
        output_item_b.associate(COMPONENT_KEY, component)
        output_item_b.associate(SAMPLE_KEY, 2)
        output_item_b.associate(ALIAS_KEY, op.ref_helper(output_item_b))
        
        blood_a = op.output(BLOOD_A).make
        blood_a.associate(SAMPLE_KEY, 1)
        blood_a.associate(KIT_KEY, kit)
        blood_b = op.output(BLOOD_B).make
        blood_b.associate(SAMPLE_KEY, 2)
        blood_b.associate(KIT_KEY, kit)
    end
    
    operations.running.each do |op|
        op.temporary[:pack_hash] = SAMPLE_PREP_UNIT
        op.temporary[:output_unit] = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
        op.temporary[:output_sample] = op.temporary[:input_sample]
        # op.temporary[:output_kit_and_unit] = [op.temporary[:output_kit], op.temporary[:output_unit]].join('')
        # op.temporary[:output_number_of_samples] = op.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        
        kit = op.temporary[:output_kit]
        unit = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
        component = op.component("sample tube 4")
        # sample = self.temporary[:output_sample]
        sample = 1
    
        raise "Kit is nil" if kit.nil?
        raise "Unit is nil" if unit.nil?
        raise "Component is nil" if component.nil?
        raise "Sample is nil" if sample.nil?
        output_item_a = op.output(DNA_A).make
        output_item_a.associate(KIT_KEY, kit)
        output_item_a.associate(UNIT_KEY, unit)
        output_item_a.associate(COMPONENT_KEY, component)
        output_item_a.associate(SAMPLE_KEY, 1)
        output_item_a.associate(ALIAS_KEY, op.ref_helper(output_item_a))
        
        output_item_b = op.output(DNA_B).make
        output_item_b.associate(KIT_KEY, kit)
        output_item_b.associate(UNIT_KEY, unit)
        output_item_b.associate(COMPONENT_KEY, component)
        output_item_b.associate(SAMPLE_KEY, 2)
        output_item_b.associate(ALIAS_KEY, op.ref_helper(output_item_b))
        
        
        dna_a = op.output(BLOOD_A).make
        dna_a.associate(SAMPLE_KEY, 1)
        dna_a.associate(KIT_KEY, kit)
        
        dna_b = op.output(BLOOD_B).make
        dna_b.associate(SAMPLE_KEY, 2)
        dna_b.associate(KIT_KEY, kit)
    end
    
    
    show do
        title "Make sure you label blood samples \"S1\" and \"S2\" in two separate tubes."
        title "Synthetic DNA should be labeled ##AK1 or ##AK2"
        # operations.each do |op|
        #     note "#{op.output(BLOOD_A).item.associations}"
        #     note "#{op.output(BLOOD_B).item.associations}" 
        #     note "#{op.output(DNA_A).item.associations}" 
        #     note "#{op.output(DNA_B).item.associations}" 
        # end
    end
    
    return {}

  end

end

```
