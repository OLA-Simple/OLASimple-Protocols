# OLASimple Graphics Test

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.






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
# OLASimple Visual Call
# author: Justin Vrana
# date: March 2018
#
#
##########################################
# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"

class Protocol
  include OLAConstants
  include OLAGraphics
  include OLALib
  def main

    def display_reading_window(kit, unit, component, sample, colorclass)
        strip_label = tube_label(kit, unit, component, sample)
        strip = make_strip(strip_label, colorclass).scale!(0.5)
        c = strip.group_children
        c.translate!(0, -35)
        strip.boundy = 50
        strip
    end
    
    show do 
      
      note display_svg(display_reading_window(4, "A", "B", 1, "bluestrip"))
    end
    
    show do
        c1 = display_svg(display_reading_window(4, "A", "B", 1, "bluestrip"))
        choices = [c1]
        select choices, var: "choice", label: "Choose something", default: 1
    end
    
    return {}
    
  end

end

```
