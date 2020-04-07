module OLAKits
  def self.kenya_kit
    {
        "name" => "kenya kit",
        "sample prep" => {
            "Unit Name" => "A",
            "Components" => {
                "magnetic beads" => "A",
                "antibodies" => "B",
                "1X PBS 1" => "C",
                "RBC lysis buffer" => "D",
                "1X PBS 2" => "E",
                "CD4 lysis buffer" => "F",
                "sample tube 1" => "G",
                "sample tube 2" => "H",
                "sample tube 3" => "J",
                "sample tube 4" => "K"
            }
        },

        "pcr" => {
            "Unit Name" => "B",
            "Components" => {
                "sample tube" => "A",
                "diluent A" => "B"
            },
            "PCR Rehydration Volume" => 40,
            "Sample Volume" => 10,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2,
        },

        "ligation" => {
            "Unit Name" => "C",
            "Components" => {
                "sample tubes" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E"
                ],
                "diluent A" => "F"
            },
            "PCR to Ligation Mix Volume" => 2.4,
            "Ligation Mix Rehydration Volume" => 24,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2
        },

        "detection" => {
            "Unit Name" => "D",
            "Components" => {
                "strips" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E"
                ],
                "stop" => "F",
                "gold" => "G",
                "diluent A" => "H"
            },
            "Number of Samples" => 2,
            "Number of Sub Packages" => 4,
            "Stop Rehydration Volume" => 40,
            "Gold Rehydration Volume" => 480,
            "Gold to Strip Volume" => 40,
            "Sample to Strip Volume" => 24,
            "Stop to Sample Volume" => 2.4,
        },

        "analysis" => {
            "Components" => {
                "strips" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E"
                ],
            },
            "Mutation Labels" => [
                "K65R",
                "K103N",
                "Y181C",
                "M184V",
                "G190A"
            ],
            "Mutation Colors" => ["red", "yellow", "green", "blue", "purple"]
        }

    }
  end

  def self.uw_kit()
    {
        "name" => "uw kit",
        "sample prep" => {
            "Unit Name" => "A",
            "Components" => {
                "sample tube 1" => "AA",
                "sample tube 2" => "AB",
            }
        },

        "pcr" => {
            "Unit Name" => "B",
            "Components" => {
                "sample tube" => "A",
                "diluent A" => "B"
            },
            "PCR Rehydration Volume" => 40,
            "Sample Volume" => 10,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2,
        },

        "ligation" => {
            "Unit Name" => "C",
            "Components" => {
                "sample tubes" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E",
                    "F"
                ],
                "diluent A" => "G"
            },
            "PCR to Ligation Mix Volume" => 1.2,
            "Ligation Mix Rehydration Volume" => 24,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2
        },

        "detection" => {
            "Unit Name" => "D",
            "Components" => {
                "strips" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E",
                    "F"
                ],
                "stop" => "G",
                "gold" => "H",
                "diluent A" => "I"
            },
            "Number of Samples" => 2,
            "Number of Sub Packages" => 4,
            "Stop Rehydration Volume" => 36,
            "Gold Rehydration Volume" => 600,
            "Gold to Strip Volume" => 40,
            "Sample to Strip Volume" => 24,
            "Stop to Sample Volume" => 2.4,
            "Sample Volume" => 2.4
        },

        "analysis" => {
            "Components" => {
                "strips" => [
                    "A",
                    "B",
                    "C",
                    "D",
                    "E",
                    "F"
                ],
            },
            "Mutation Labels" => [
                "K65R",
                "K103N",
                "V106M",
                "Y181C",
                "M184V",
                "G190A"
            ],
            "Mutation Colors" => ["red", "yellow", "white", "green", "blue", "purple"]
        }

    }
  end
end