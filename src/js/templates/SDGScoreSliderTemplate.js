
import { camelCase, uniqueId } from 'lodash';
import { sdgScoreSetting } from '../utilities/settings';
import PubSub from '../utilities/pubsub';

class SDGScoreSliderTemplate extends HTMLElement {
    constructor() {
        super();
    }

    connectedCallback() {
        const label = this.getAttribute('label') ? this.getAttribute('label') : ''; // Attribute which concates a unquie string to the DOM_Ids to allow for reuse of the template
        const sliderMin = this.getAttribute('min') ? Number(this.getAttribute('min')) : 1;
        const sliderMax = this.getAttribute('max') ? Number(this.getAttribute('max')) : 10;
        const sliderInitValue = this.getAttribute('value') ? Number(this.getAttribute('value')) : 1;
        const sliderStep = this.getAttribute('step') ? Number(this.getAttribute('step')) : 1;
        const template_id = uniqueId(camelCase(label));

        this.innerHTML = `
            <div id="sdg_slider_container_${template_id}">                
                <span id='sdg_slider_label_${template_id}' class="sdgSettingsSliderLabel">${label}: <span id='sdg_slider_label_value_${template_id}'>${sliderInitValue}</span></span>
                <input id='sdg_slider_${template_id}' value='${sliderInitValue}' type="range" min="${sliderMin}" max="${sliderMax}" step="${sliderStep}" list="sdg_slider_steplist_${template_id}" class="sdgSettingsSlider">
                <datalist id="sdg_slider_steplist_${template_id}" class="sdgSettingsSliderSteplist">
                    <option value='${sliderMin}' label='${sliderMin}'></option>
                    <option value='${sliderMax}' label='${sliderMax}'></option>
                </datalist>
            </div>
        `;

        document.getElementById(`sdg_slider_${template_id}`).addEventListener('change', (event) => {
            const sdgScoreSetting_variablePath = this.getAttribute('sdgScoreSetting_variablePath'); // This attribute, stores the path for the setting variable 'sdgScoreSetting', NOTE: Start path from the first level child key! Not from 'sdgScoreSetting'
            const updatedSettingValue = this.accessNestedObject(sdgScoreSetting, sdgScoreSetting_variablePath, Number(event.target.value));
            document.getElementById(`sdg_slider_label_value_${template_id}`).innerText = updatedSettingValue;
            PubSub.publish('recalculateRegionScore', true); // Trigger score recalculation on update
        });

    }

    accessNestedObject(obj, path, newValue) {
        const keys = path.split('.');
        let result = obj;

        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];

            if (i === keys.length - 1) {
                // Last key in the path, set the new value
                result[key] = newValue;
            } else if (result && result.hasOwnProperty(key)) {
                // Continue traversing the object
                result = result[key];
            } else {
                return undefined; // Key doesn't exist in the object
            }
        }
        return newValue; // Return the updated value
    };
};

customElements.define('sdg_score_slider-template', SDGScoreSliderTemplate);