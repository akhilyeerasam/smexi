import { capitalize } from 'lodash';
import { sdgScoreSetting } from '../utilities/settings';

class SDGScoreSettingsTemplate extends HTMLElement {
    constructor() {
        super();
    }

    connectedCallback() {
        this.innerHTML = `
            <div id="sdg_settings" class="column is-12">

                <div id="region_settings" class="column info_section">
                    <h4 class="sectionHeading">Region Settings</h4>
                    <p class="sectionDescription">Size is in acres as per calculation function used, defined as the minimum size upon which calculations for livability/sustainability will be performed</p>

                    <sdg_score_slider-template label='Region Size' sdgScoreSetting_variablePath='regionSettings.idealSize' min='${sdgScoreSetting.regionSettings.sizeRangeSlider.min}', max='${sdgScoreSetting.regionSettings.sizeRangeSlider.max}', value='${sdgScoreSetting.regionSettings.idealSize}'></sdg_score_slider-template>
                </div>

                <div id="education_settings" class="column info_section">
                    <h4 class="sectionHeading">
                        Education Settings
                        <div class="info_tooltip_container">
                            <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                            <div class="info_tooltip">
                                Expected Years of Schooling - Number of schooling years defined nationally as the ideal value to be achieved.
                                Mean Years of Schooling - The expected/ground reality of the mean number of years recoreded from the population on an average of the national dataset
                            </div>
                        </div>
                    </h4>
                    <p class="sectionDescription">Education</p>
                    ${
                        Object.keys(sdgScoreSetting.educationScoreSettings.idealCounts).map(element => {
                            return `<sdg_score_slider-template label='${capitalize(element)}' sdgScoreSetting_variablePath='educationScoreSettings.idealCounts.${element}' min='${sdgScoreSetting.educationScoreSettings.countRangeSlider.min}', max='${sdgScoreSetting.educationScoreSettings.countRangeSlider.max}', value='${sdgScoreSetting.educationScoreSettings.idealCounts[element]}'></sdg_score_slider-template>`;
                        }).join('')
                    }
                </div>

                <div id="amenities_settings" class="column info_section">
                    <h4 class="sectionHeading">Amenities Settings</h4>
                    <p class="sectionDescription">Amenities</p>
                    ${
                        Object.keys(sdgScoreSetting.amenitiesScoreSettings.idealCounts).map(categoryName => {
                            return `<sdg_score_slider-template label='${capitalize(categoryName)} Count' sdgScoreSetting_variablePath='amenitiesScoreSettings.idealCounts.${categoryName}' min='${sdgScoreSetting.amenitiesScoreSettings.countRangeSlider.min}', max='${sdgScoreSetting.amenitiesScoreSettings.countRangeSlider.max}', value='${sdgScoreSetting.amenitiesScoreSettings.idealCounts[categoryName]}'></sdg_score_slider-template>`;
                        }).join('')
                    }
                </div>

                <div id="transport_settings" class="column info_section">
                    <h4 class="sectionHeading">Transport Settings</h4>
                    ${
                        Object.keys(sdgScoreSetting.transportScoreSettings.idealCounts).map(transportType => {
                            return `<sdg_score_slider-template label='${capitalize(transportType)} Platform Count' sdgScoreSetting_variablePath='transportScoreSettings.idealCounts.${transportType}' min='${sdgScoreSetting.transportScoreSettings.countRangeSlider.min}', max='${sdgScoreSetting.transportScoreSettings.countRangeSlider.max}', value='${sdgScoreSetting.transportScoreSettings.idealCounts[transportType]}'></sdg_score_slider-template>`;
                        }).join('')
                    }
                </div>

                <div id="landuse_settings" class="column info_section">
                    <h4 class="sectionHeading">Landuse Settings</h4>
                    <p class="sectionDescription">Ideal landuse percentages for each category are to be defined here. Note: If the total crosses 100%, the formula normalises</p>
                    ${
                        Object.keys(sdgScoreSetting.landuseScoreSettings.idealCounts).map(categoryName => {
                            return `<sdg_score_slider-template label='${capitalize(categoryName)} Percentage' sdgScoreSetting_variablePath='landuseScoreSettings.idealCounts.${categoryName}' min='${sdgScoreSetting.landuseScoreSettings.countRangeSlider.min}' max='${sdgScoreSetting.landuseScoreSettings.countRangeSlider.max}' value='${sdgScoreSetting.landuseScoreSettings.idealCounts[categoryName]}'></sdg_score_slider-template>`;
                        }).join('')
                    }
                </div>

            </div>
        `;
    };
}

customElements.define('sdg_score_settings-template', SDGScoreSettingsTemplate);



