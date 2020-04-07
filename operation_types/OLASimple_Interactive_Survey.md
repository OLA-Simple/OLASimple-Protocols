# OLASimple Interactive Survey

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.






### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
class Protocol

  def main

    show do
        title "Thank you for taking part in the OLASimple study!"
        
        note "Please continue to take part in an interactive survey"
        
    end
    choices = "Strongly agree", "Agree", "Neutral", "Disagree", "Strongly disagree"
    
    show do
        title "Section: Demographics"
        get "text", var: "age", label: "What is your age?", default: 50
        select ["male", "female", "none"], var: "gender", label: "What is your gender?", default: 2
        select ["no schooling", "nursery to secondary", "some secondary, no diploma", "completed secondary school or equivalent", 
                "some university credit, no degree", "trade school", "associate degree", "Bachelor's", "Master's", "Professional", "Doctorate"],
                var: "education", label: "What is your highest level of education?", default: 0
    end
    
    show do
        title "Section: Technician Experience"
        get "text", var: "years", label: "How many years of experience do you have as a lab technician?", default: 1
        select ["yes", "no"], var: "hours", label: "Have you worked with HIV before today?", default: 0
        select ["yes", "no"], var: "hours", label: "Have you ever performed a PCR?", default: 0
        select ["yes", "no"], var: "hours", label: "Have you ever used a thermocycler?", default: 0
    end
    
    show do
        title "Section: Self Evaluation"
        note "<b>For each section, select from the following choices:</b>"
        select choices, var: "question1", label: "I consider myself good at pipetting", default: 2
        select choices, var: "question2", label: "I consider myself good at laboratory techniques", default: 2
        select choices, var: "question3", label: "I enjoy lab work", default: 2
    end
    
    show do
        title "Section: Kit Evaluation"
        note "<b>For each section, select from the following choices:</b>"
        select choices, var: "question1", label: "I found the kit to be easy", default: 2
        select choices, var: "question2", label: "I found the instructions were clear", default: 2
        select choices, var: "question3", label: "I understood the purpose of the kit", default: 2
        select choices, var: "question4", label: "I understood the purpose of the strips", default: 2
    end
    
    show do
        title "Section: Digital Guidance Evaluation"
        note "<b>For each section, select from the following choices:</b>"
        select choices, var: "question1", label: "I found the instructions clear", default: 2
        select choices, var: "question2", label: "I thought the digital guidance was useful", default: 2
        select choices, var: "question3", label: "I would have preferred a paper protocol over digital guidance", default: 2
    end
    
    show do
        title "Written Section 1"
        note "<b>For each section, answer the following questions</b>"
         get "text", var: "written11", label: "What did you like best about using this kit?", default: ""
         get "text", var: "written12", label: "Which instruction(s) were not easy to follow? Please explain.", default: ""
         get "text", var: "written13", label: "What advice do you have for us to make kit and instructions easier to use?", default: ""
    end
    
    show do
        title "Written Section 2"
        note "<b>For each section, answer the following questions</b>"
         get "text", var: "written21", label: "What did you like best about using the digital guidance?", default: ""
         get "text", var: "written22", label: "Which parts of the guidance were not easy to follow?", default: ""
         get "text", var: "written23", label: "What advice do you have for us to make the digital guidance easier to use?", default: ""
    end
    
    return {}
    
  end

end

```
