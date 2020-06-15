var config = {

  tagline: "The Laboratory</br>Operating System",
  documentation_url: "http://localhost:4000/aquarium",
  title: "OLA Simple Workflow",
  navigation: [

    {
      category: "Overview",
      contents: [
        { name: "Introduction", type: "local-md", path: "README.md" },
        { name: "About this Workflow", type: "local-md", path: "ABOUT.md" },
        { name: "License", type: "local-md", path: "LICENSE.md" },
        { name: "Issues", type: "external-link", path: 'https://github.com/OLA-Simple/OLASimple-Protocols/issues' }
      ]
    },

    

      {

        category: "Operation Types",

        contents: [

          
            {
              name: 'Fluorescence Analysis',
              path: 'operation_types/Fluorescence_Analysis' + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLASimple Ligation',
              path: 'operation_types/OLASimple_Ligation' + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLASimple PCR',
              path: 'operation_types/OLASimple_PCR' + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLASimple Paper Detection',
              path: 'operation_types/OLASimple_Paper_Detection' + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLASimple RNA Extraction',
              path: 'operation_types/OLASimple_RNA_Extraction' + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLASimple Sample Preparation',
              path: 'operation_types/OLASimple_Sample_Preparation' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Pipette Training',
              path: 'operation_types/Pipette_Training' + '.md',
              type: "local-md"
            },
          

        ]

      },

    

    

      {

        category: "Libraries",

        contents: [

          
            {
              name: 'JobComments',
              path: 'libraries/JobComments' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'NetworkRequests',
              path: 'libraries/NetworkRequests' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLAConstants',
              path: 'libraries/OLAConstants' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLAGraphics',
              path: 'libraries/OLAGraphics' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLAKitIDs',
              path: 'libraries/OLAKitIDs' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLAKits',
              path: 'libraries/OLAKits' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLALib',
              path: 'libraries/OLALib' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'OLAScheduling',
              path: 'libraries/OLAScheduling' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'RNAExtractionResources',
              path: 'libraries/RNAExtractionResources' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'SVGGraphics',
              path: 'libraries/SVGGraphics' + '.html',
              type: "local-webpage"
            },
          

        ]

    },

    

    
      { category: "Sample Types",
        contents: [
          
            {
              name: 'OLASimple Sample',
              path: 'sample_types/OLASimple_Sample'  + '.md',
              type: "local-md"
            },
          
        ]
      },
      { category: "Containers",
        contents: [
          
            {
              name: 'OLA Detection Strips',
              path: 'object_types/OLA_Detection_Strips'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLA Ligation Stripwell',
              path: 'object_types/OLA_Ligation_Stripwell'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLA PCR',
              path: 'object_types/OLA_PCR'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLA plasma',
              path: 'object_types/OLA_plasma'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'OLA viral RNA',
              path: 'object_types/OLA_viral_RNA'  + '.md',
              type: "local-md"
            },
          
        ]
      }
    

  ]

};
