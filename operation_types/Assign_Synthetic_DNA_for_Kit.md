# Assign Synthetic DNA for Kit

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.


### Parameters

- **Kit Number** 

### Outputs


- **Sample 1** [S]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLASimple Synthetic DNA")'>OLASimple Synthetic DNA</a>

- **Sample 2** [S]  
  - <a href='#' onclick='easy_select("Sample Types", "OLASimple Sample")'>OLASimple Sample</a> / <a href='#' onclick='easy_select("Containers", "OLASimple Synthetic DNA")'>OLASimple Synthetic DNA</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
needs "OLASimple/OLAConstants"

class Protocol
  include OLAConstants
  
  def main
      
    show do
        title "This protocol assigns creates two samples and assigns a kit number " \
        "for the rest of the OLASimple protocol."
    end
    
    # do pre workflow checks
    if operations.length > 1
        raise "Batch size greater than 2 not supported. Please have supervisor rebatch." 
    end

    kit_nums = operations.map { |op| op.input("Kit Number").value }
    if kit_nums.length > 1
        raise "Multiple kits found. Please replan." 
    end
    kit_num = kit_nums.first
    
    
    operations.retrieve.make
    
    # assign pre-labels to output tubes
    operations.running.each do |op|
        s1 = op.output("Sample 1").item
        s1.associate(KIT_KEY, kit_num)
        s1.associate(UNIT_KEY, "")
        s1.associate(COMPONENT_KEY, "A")
        s1.associate(SAMPLE_KEY, "A")
        s2 = op.output("Sample 2").item
        s2.associate(KIT_KEY, kit_num)
        s2.associate(UNIT_KEY, "")
        s2.associate(COMPONENT_KEY, "A")
        s2.associate(SAMPLE_KEY, "B")
    end
    
    show do
        title "The next protocol is \"OLASimple PCR\"."
        title "Please assign a technician to run kit #{kit_num}."
        warning "Remember, only one technician can run a kit."
    end
    
    return {}
    
  end

end

```
