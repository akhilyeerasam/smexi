import { enums } from "../../utilities/enums";
import { regionInfoBarSettings } from "../../utilities/settings";

class FixedRegionInfoBarCustomTemplate extends HTMLElement {
    constructor() {
        super();
    }

    connectedCallback() {
        this.innerHTML = `
            <div id="${enums.region_info_bar_container_Id}" class="region_info_bar_container">

                <div id="app_info_control" class="column is-12">
                    <div id="app_intro" class="column info_section">
                        <h4 class="sectionHeading">Welcome</h4>
                        <p class="sectionDescription">
                            We present this tool as a solution for exploration of SDG Indicators on a Small Scale.
                        </p>
                    </div>

                    <div id="region_view_controls" class="column info_section">
                        <div>
                            <p class="sectionDescription">Select Region:</p>
                            <div class="info_tooltip_container">
                                <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                                <div class="info_tooltip">
                                    Muncipality regions are an aggregation of multiple statistical regions.
                                </div>
                            </div>
                            <div class="select is-small">
                                <select id="${enums.select_region_view_Id}" name="Region">
                                    <option value="statistical">Statistical Region View</option>
                                    <option value="muncipal">Muncipality Region View</option>
                                </select>
                            </div>
                        </div>
                        <div id="compare_regions_container" style="padding-top: 10px;">
                            <p class="sectionDescription">Compare regions:</p>
                            <div class="info_tooltip_container">
                                <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                                <div class="info_tooltip">
                                    Before triggering the compare, ensure a region is already selected!
                                </div>
                            </div>
                            <button id="${enums.compare_regions_button_Id}" class="button is-small">Compare Regions</button>
                        </div>

                        <div style="padding-top: 10px;">
                            <p class="sectionDescription">SDG Score Settings</p>
                            <div class="info_tooltip_container">
                                <i class="fa-solid fa-circle-info" style="color: #050505;"></i>
                                <div class="info_tooltip">
                                    The SDG score settings control the score assigned to a region. Updating the values will affect the score!
                                </div>
                            </div>
                            <button id="${enums.sdg_score_settings_button_Id}" class="button is-small">SDG Score Settings</button>
                        </div>
                    </div>
                </div>

                <region_info_bar-template concat-id="${regionInfoBarSettings.defaultRegionInfoBarSettings.concatId}"></region_info_bar-template>

        </div>
        `;
    }
}

customElements.define('fixed_region_info_bar-custom-template', FixedRegionInfoBarCustomTemplate);
