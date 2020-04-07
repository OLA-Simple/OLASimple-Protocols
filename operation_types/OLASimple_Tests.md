# OLASimple Tests

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.






### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "OLASimple/OLALib"
class Protocol
include OLALib
  def main

    operations.retrieve.make
    
    tin  = operations.io_table "input"
    tout = operations.io_table "output"
    u = Upload.find(21404)
    show do 
        # raw display_upload(Upload.find(21404))
        # note "#{u.name}"
      title "Input Table"
      table tin.all.render
    end
    
    show do
        warning "<h1>A really big warning!</h1>" 
    end
    
    show do
        raw display_strip_section(u, 0, 6, "50%")
    end
    
    show do
        raw display_strip_section(u, 1, 6, "50%")
    end
    
    show do 
      title "Output Table"
      table tout.all.render
    end
    
    operations.store
    
    return {}
    
  end
  
  def display_strip_section(upload, display_section, num_sections, size)
      p = Proc.new do
          x = 100.0/num_sections
          styles = []
          num_sections.times.each do |section|
              x1 = 100 - (x * (section+1)).to_i
              x2 = (x*(section)).to_i
              styles.push(".clipimg#{section} { clip-path: inset(0% #{x1}% 0% #{x2}%); }")
          end
          style = "<head><style>#{styles.join(' ')}</style></head>"
          note style
          note "#{styles}"
          note "<img class=\"clipimg#{display_section}\" src=\"#{upload.expiring_url}\" width=\"#{size}\"></img>" 
      end
      ShowBlock.new(self).run(&p)
  end
  
end

```
