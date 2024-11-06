# SMEXI
Cities worldwide are confronting complex environmental, social, economic, and governance challenges, exacerbated by crises like the Covid-19 pandemic and military conflicts. Addressing these issues requires a comprehensive approach focused on sustainable development that meets current needs without compromising future generations.

The United Nations Sustainable Development Goals (SDGs), established in 2015, provide a framework for tackling interconnected social, economic, and environmental challenges. However, effectively promoting sustainable development necessitates a clear understanding of regional conditions through relevant indicators. Unfortunately, many existing tools for analyzing SDGs are limited to macro-level assessments, failing to capture the diverse realities within cities.

To address this gap, the SMEXI (Small Scale Exploration of SDG Indicators) project was initiated at DFKI. Focusing on Kaiserslautern, Germany, SMEXI offers an interactive digital platform for tracking SDGs at a localized scale. Developed in late 2023, the prototype utilizes data from city administration and publicly available sources, allowing users to conduct fine-grained analyses and compare different urban areas.

Released as open source in October 2024, we aim to further develop SMEXI for various sustainability scenarios and invite others to utilize this tool in their work. Please don’t hesitate to reach out for collaboration or inquiries!

## Getting started

To make it easy for you to get started with the solution, here's a list of recommended next steps.

**Prerequisites:** 
- Elasticsearch & Kibana > 7.17.4
- Node > 21.5.0

**Setup**
- To setup the index files, we have created a shell script to support the data imports. Can be found at - `~/index_tools/projectIndexGenerator.sh`
- New indices can be imported through this file by updating the code.
- The solution works through use of configuration and settings files. Found under the `src/js/utilities` folder. Detailed information on the configuration can be document linked in the [reference section](#references).
- A sample `PHP` file is availble for use in the `index_tools` folder, which will support communication between the indices and the files of the `dist` folder.
- Before you can start working on the project locally, install the required node modules using the `npm install` command. In the event of any errors/vulnerabilities run the command `npm audit fix` which should resolve the issues. Please reach out to the code owners if the build process fails.

**Run project locally**
- To ensure the index data is available to access run the command `elasticsearch`. To verify the indices are available, open `http://localhost:9200/` for the status.
    - **Note**: If the elasticsearch port (default `9200`) is updated to another, the port reference must be updated in the code in the file `src/js/models/ElasticSearchModel.js` for the key `elasticsearchBaseUrl` under the variable `defaults`.
- In parallel run `kibana`, this will offer a UI to view the elasticsearch index data available at the port 5601 (`http://localhost:5601/`)
- The `dist` folder generates the bundle files of the project, which are generated on building the project. Which can be generated using the commands `npm run build` (run in parallel with `elasticsearch`) or `npm run build:once`. 
  - Differences between the build commands.

    | Feature                | build                            | build:once                                        |
    |------------------------|----------------------------------|--------------------------------------------------|
    | Cleans dist Folder     | No                               | Yes (cleans before building)                     |
    | Execution Intent       | Regular development builds       | One-time, clean builds (ideal for production)   |
    | Typical Usage          | Frequent during development      | For final builds or deployment                   |
- The `index.html` file can be used to view the project run locally.


## Project Structure

We briefly explain the project structure in this section.

- webpack.js 
    Definiation of entry file (index.js) from which the prokect starts exec and the name of the final bindle file and its location defined.
- index_tools
    - Files which support import of data into elastic indices from diverse data sources such as `csv, JSON, XML and more`
    - `PHP` file to support deployment
- src
    - js
    - styles 
    - index.js
    - index.html


## References

A detailed documentation for the project can be found at the [link](https://scll.dfki.de/documents/theses/2024_MA-Yeerasam.pdf)
