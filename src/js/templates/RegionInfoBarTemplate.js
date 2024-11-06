class RegionInfoBarTemplate extends HTMLElement {
    constructor() {
        super();
    }

    connectedCallback() {
        const template_id = this.getAttribute('concat-id') ? this.getAttribute('concat-id') : ''; // Attribute which concates a unquie string to the DOM_Ids to allow for reuse of the template
        this.innerHTML = `
            <div id="side_bar${template_id}" class="column is-12">

                <div id="region_info${template_id}" class="column info_section">
                    <h4 class="sectionHeading">
                        Region Selected
                        <div class="info_tooltip_container">
                            <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                            <div class="info_tooltip">
                                The region score is calculated using data from a few dimensions, such as Amenities and Transport. It is NOT a definite answer for the region!
                                Score will be a value between 0-1.    
                            </div>
                        </div>
                    </h4>
                    <p class="sectionDescription" id="regionSelected${template_id}">-</p>
                    <br/>
                    <p class="regionScore">Region Score: <span id="regionScore${template_id}"></span></p>
                    <p id="regionScore_errorMessage${template_id}" class="regionScoreErrorMessage" style="display:none">Note: Score is zero as the region size is less than the default size setting found under SDG score settings</p>
                </div>

                <div id="education_bars${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Educational Qualification Distribution</h4>
                    <p class="sectionDescription">Comparision of population by educational qualification.</p>
                    <br/>
                </div>

                <div id="income_visual${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Income Distribution</h4>
                    <p class="sectionDescription">Comparision of population by income distribution.</p>
                    <br/>
                </div>

                <div id="population_age_visual${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Population Age Distribution</h4>
                    <p class="sectionDescription">Comparision of the age of population.</p>
                    <br/>
                </div>

                <div id="population_diversity${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Population Diversity</h4>
                    <div class="columns">
                        <div id="gender_diversity${template_id}" class="column">
                            <p class="sectionDescription">Female Diversity</p>
                        </div>
                        <div id="nationality_diversity${template_id}" class="column">
                            <p class="sectionDescription">Foreigner Diversity</p>
                        </div>
                    </div>
                </div>

                <div id="year_gender_diversity_visual${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Year vs Gender Diversity</h4>
                    <p class="sectionDescription">Pyramid chart comparison of gender diversity on a yearly basis.</p>
                </div>

                <div id="landuse_info${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Land Use</h4>
                    <div class="columns sectionDescription">
                        <div class="column is-6">
                            <p>Total Area</p>
                            <p id="landuse_totalArea${template_id}">-</p>
                        </div>
                    </div>
                    <p class="sectionDescription">Land Use Occupancy By Category</p>
                    <div id="landuse_visual${template_id}"></div>
                </div>

                <div id="transport_lines${template_id}" class="column info_section">
                    <h4 class="sectionHeading">
                        Transport Lines
                        <div class="info_tooltip_container">
                            <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                            <div class="info_tooltip">
                                The transport options listed only pass through the region, not necessarily having a stop
                            </div>
                        </div>
                    </h4>
                    <p class="sectionDescription">
                        Map visualises the public transport lines and platforms available in the area.
                    </p>
                </div>

                <div id="amenities${template_id}" class="column info_section">
                    <h4 class="sectionHeading">
                        Amenities
                    </h4>
                    <p class="sectionDescription">Map visualises the daily amenities options available.</p>
                </div>

                <div id="car_fuel_type${template_id}" class="column info_section">
                    <h4 class="sectionHeading">Distribution Of Car Fuel Types</h4>
                    <p class="sectionDescription">Visual of the distribution of the cars based on the type of fuel they require.</p>
                    <br/>    
                </div>

            </div>
        `;
    }
}

customElements.define('region_info_bar-template', RegionInfoBarTemplate);
