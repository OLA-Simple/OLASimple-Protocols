# test

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.
### Inputs


- **KIT key hello** [c]  
  - NO SAMPLE TYPE / NO CONTAINER





### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# frozen_string_literal: true

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
    # operations.retrieve
    operations.first.field_values[0].retrieve
    show do
        note operations.first.field_values[0].item
    end

    {}

  end

end

```
