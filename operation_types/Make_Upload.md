# Make Upload

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.






### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
needs "OLASimple/OLALib"

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLALib

  def main

    operations.retrieve.make
    
    show do
        note "<img src=\"http://0.0.0.0:8080/assets/biofab-logo.jpg\" />" 
    end
    
    result = show do
        title "Upload a picture or a video"
        
        upload var: :files
    end
    
    upload_hashes = result[:files]
    
    show do
        upload_hashes.each do |uhash|
            note "#{uhash[:name]} #{uhash[:id]}"
            raw display_upload(Upload.find(uhash[:id]))
        end
    end
    
    operations.store
    
    return {}
    
  end

end

```
