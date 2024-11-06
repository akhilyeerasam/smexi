import { MapController } from "./MapController";
import { RegionInfoBarController } from "./RegionInfoBarController";
import { enums } from '../utilities/enums';
import { regionInfoBarSettings } from "../utilities/settings";
import PubSub from '../utilities/pubsub';

export class AppController {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    map_controller; // Map Controller, all functions which affect the map go in this controller
    regionInfoBar_controller; // The primary sidenav container controller, initially available on page load

    /******************************************************************************************************************************/
    // *** Constructor and custom destroyer function ***
    /******************************************************************************************************************************/
    constructor() {
        this.#_init();
        this.#_initEventListeners();

        PubSub.publish('updateRegionInfoBarBoundToMap', this.regionInfoBar_controller); // Initialize to default regionInfoBarController object to bind to the mapController object
    };

    destroyer = () => {
        // Unsubscribe to prevent memory leakage and any unwanted calls to an instance of this class when instance is deleted to keep memory clean and code execution smooth
        PubSub.unsubscribe('updateRegionInfoBarBoundToMap');
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    #_init() {
        this.map_controller = new MapController();
        this.regionInfoBar_controller = new RegionInfoBarController(this.map_controller.m_mapModel, regionInfoBarSettings.defaultRegionInfoBarSettings);
    };

    #_initEventListeners() {
        const map_model = this.map_controller.m_mapModel;
        let currentRegionInfoBarController_bound; // Tracks the current 'regionInfoBar_controller' bound to the mapController object

        document.getElementById(`${enums.select_region_view_Id}`).addEventListener('change', (event) => {
            if (event.target.value === 'muncipal') {
                map_model.hideOverlayLayer(enums.overlay_layer_KL_statistical_regions);
                map_model.showOverlayLayer(enums.overlay_layer_KL_muncipality_regions);
            } else if (event.target.value === 'statistical') {
                map_model.hideOverlayLayer(enums.overlay_layer_KL_muncipality_regions);
                map_model.showOverlayLayer(enums.overlay_layer_KL_statistical_regions);
            }
        });

        let compareModeFlag = false;
        document.getElementById(`${enums.compare_regions_button_Id}`).addEventListener('click', (event) => {
            if (compareModeFlag === false) {
                if (this.regionInfoBar_controller && (!this.regionInfoBar_controller.m_mapOnClickData || !this.regionInfoBar_controller.m_mapOnClickData.regionRecord || Object.keys(this.regionInfoBar_controller.m_mapOnClickData.regionRecord).length === 0)) {
                    alert('To compare regions, first a region on the map to compare against must be selected!');
                    return;
                }

                const mapContainer = document.getElementById(`${enums.map_container_Id}`);
                const region_info_bar_compareHTML = `
                    <div id='${enums.region_info_bar_container_Id}${regionInfoBarSettings.compareRegionInfoBarSettings.concatId}' class='region_info_bar_compare_container'>
                        <region_info_bar-template concat-id='${regionInfoBarSettings.compareRegionInfoBarSettings.concatId}'></region_info_bar-template>
                    </div>
                `;
                mapContainer.insertAdjacentHTML("beforeend", region_info_bar_compareHTML);

                this.compare_regionInfoBar_controller = new RegionInfoBarController(map_model, regionInfoBarSettings.compareRegionInfoBarSettings);
                PubSub.publish('updateRegionInfoBarBoundToMap', this.compare_regionInfoBar_controller);

                document.getElementById(`${enums.compare_regions_button_Id}`).innerText = 'Stop Comparison';

                // The compare_region and sdg_score_settings container occupy the same location on the DOM, to prevent both from being open at the same disable one when other is open
                document.getElementById(`${enums.sdg_score_settings_button_Id}`).setAttribute('disabled', true);

                this.#_handleCompareRegionScrollSync();

                const scrollSyncContainerHTML = `
                    <div id="scrollSyncContainer" class="scroll_Sync_Container">
                        <label class="checkbox">
                            <input type="checkbox" id="compare_regions_scroll_sync" checked/>
                                <span>Enable Scroll Sync</span>
                        </label>
                    </div>`;
                document.getElementById('compare_regions_container').insertAdjacentHTML("beforeend", scrollSyncContainerHTML);
            } else {
                PubSub.publish('updateRegionInfoBarBoundToMap', this.regionInfoBar_controller); 
                document.getElementById(`${enums.region_info_bar_container_Id}${regionInfoBarSettings.compareRegionInfoBarSettings.concatId}`).remove();
                this.compare_regionInfoBar_controller.destroyer();
                delete this.compare_regionInfoBar_controller;
                document.getElementById(`${enums.compare_regions_button_Id}`).innerText = 'Compare Regions';
                document.getElementById(`${enums.sdg_score_settings_button_Id}`).removeAttribute('disabled');
            }

            compareModeFlag = !compareModeFlag;
        });

        // Update the regionInfoBarController object which is bound to the mapController. This is required to enable a smooth and singular place to handle swithing/updating regions in compare mode
        PubSub.subscribe('updateRegionInfoBarBoundToMap', (regionInfoBar_controller) => {
            if (currentRegionInfoBarController_bound) {
                document.getElementById(`${enums.region_info_bar_container_Id}${currentRegionInfoBarController_bound.regionInfoBarSettings.concatId}`).classList.remove('region_info_bar_container_active');
            }

            this.map_controller.bindSideNavController(regionInfoBar_controller);
            document.getElementById(`${enums.region_info_bar_container_Id}${regionInfoBar_controller.regionInfoBarSettings.concatId}`).style.borderColor = regionInfoBar_controller.regionInfoBarSettings.color;
            document.getElementById(`${enums.region_info_bar_container_Id}${regionInfoBar_controller.regionInfoBarSettings.concatId}`).classList.add('region_info_bar_container_active');
            currentRegionInfoBarController_bound = regionInfoBar_controller;
        });

        let sdgScoreSettingsModeFlag = false;
        document.getElementById(`${enums.sdg_score_settings_button_Id}`).addEventListener('click', (event) => {
            if (sdgScoreSettingsModeFlag === false) {
                const mapContainer = document.getElementById(`${enums.map_container_Id}`);
                const sdg_score_settingsHTML = `
                <div id="sdg_score_settings_container" class="sdg_settings_container">
                    <sdg_score_settings-template></sdg_score_settings-template>
                </div>
                `;
                mapContainer.insertAdjacentHTML("beforeend", sdg_score_settingsHTML);
    
                document.getElementById(`${enums.sdg_score_settings_button_Id}`).innerText = 'Close SDG Score Settings';

                // The compare_region and sdg_score_settings container occupy the same location on the DOM, to prevent both from being open at the same disable one when other is open
                document.getElementById(`${enums.compare_regions_button_Id}`).setAttribute('disabled', true);
            } else {
                document.getElementById('sdg_score_settings_container').remove();
                document.getElementById(`${enums.sdg_score_settings_button_Id}`).innerText = 'SDG Score Settings';
                document.getElementById(`${enums.compare_regions_button_Id}`).removeAttribute('disabled');

                PubSub.publish('recalculateRegionScore', true); // Trigger score recalculation on update
            }

            sdgScoreSettingsModeFlag = !sdgScoreSettingsModeFlag;
        });
    }

    #_handleCompareRegionScrollSync() {
        // Start - Code subsection block to handle regon_info_bar(s) (default and compare) sync scroll ----------------------------------------------------------------------------------------------------
        const defaultRegionInfoBar_div = document.getElementById('region_info_bar_container');
        const compareRegionInfoBar_div = document.getElementById('region_info_bar_container_compare');
        const section2Offset = document.querySelector('#app_info_control').offsetHeight;
        let isSyncingScroll = false;

        // Add event listener for scroll on defaultRegionInfoBar_div
        defaultRegionInfoBar_div.addEventListener('scroll', function() {
            const scrollSyncCheckboxElement = document.getElementById('compare_regions_scroll_sync');
            if (!isSyncingScroll && defaultRegionInfoBar_div.scrollTop > section2Offset && scrollSyncCheckboxElement.checked) {
                isSyncingScroll = true;
                compareRegionInfoBar_div.scrollTop = defaultRegionInfoBar_div.scrollTop - section2Offset;
                isSyncingScroll = false;
            }
        });
        // End - Code subsection block to handle regon_info_bar(s) (default and compare) sync scroll ------------------------------------------------------------------------------------------------------
    }

}