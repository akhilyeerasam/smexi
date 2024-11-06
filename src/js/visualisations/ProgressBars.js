import { appSetting } from '../utilities/settings';
import { round, cloneDeep } from 'lodash';

export class ProgressBars {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    m_parentRef;
    m_progressBarsRef;
    m_progressBarPeriodTimelineRef;

    m_progressBarConfig;
    m_progressBarPostValueSymbol;
    m_progressBarTotal = 0;

    constructor(progressBarConfig, progressBarPostValueSymbol) {
        this.m_progressBarConfig = progressBarConfig;

        this.m_parentRef = document.getElementById(this.m_progressBarConfig.DOM_ContainerId);
        if (this.m_progressBarConfig.data) {
            this.createProgressBars(this.m_progressBarConfig.data); // init_data(first param) will contain records without values for the initial view of the visualisation
            this.#_generatePeriodTimelineContainerDOM({[this.m_progressBarConfig.periodSettings ? this.m_progressBarConfig.periodSettings.key : undefined]: []});
        }

        this.m_progressBarPostValueSymbol = (progressBarPostValueSymbol !== undefined) ? progressBarPostValueSymbol : '%';
    };

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/
    /**
     * @param {[{name:<>, key:<>, value:<>, color:<>}]} data  Array of records used to generate the progress bars. 
    */
    createProgressBars = (data) => {
        let parentProgressBar_HTML = ``;
        data.forEach(record => {
            const singleProgressBarContainer_HTML = `<div class="progressBarContainer">
                                                        <span class='progressBar_CategoryText progressBar_CategoryText_Ellipsis'>${record.name}</span>
                                                        <span class='progressBar_CategoryValue' key="${record.key}">${record.value ? (this.#_processDisplayValue(record.value, this.m_progressBarPostValueSymbol)) : '-'}</span>
                                                        <div class="progressBar">
                                                            <span class="progressBarValue" key="${record.key}" style="width:${record.value ? this.#_processBarValue(record.value) : '0%'}; background-color:${record.color ? record.color : appSetting.progressBarColor}; display: block;"></span>
                                                        </div>
                                                    </div>`;
            parentProgressBar_HTML += singleProgressBarContainer_HTML;
        });

        const progressBarsContainerId = `ProgressBarRef_${Date.now()}_${this.m_parentRef.id}`;
        this.m_parentRef.insertAdjacentHTML("beforeend", `<div id='${progressBarsContainerId}'>${parentProgressBar_HTML}</div>`);
        this.m_progressBarsRef = document.getElementById(progressBarsContainerId);
    };

    /**
     * 
     * @param {{}} recordData
     * @param {boolean} dimensionsPreservedFlag     Boolean value defines if the categories/dimensions are to be preserved
     */
    updateVisual = (recordData, dimensionsPreservedFlag) => {
        let data;
        if (this.m_progressBarConfig && this.m_progressBarConfig.periodSettings) {
            // The 'initPeriodKey', obtains the first time period to be displayed initially. Either an ascending/decending value of all possible time periods, as defined from the config
            const initPeriodKey = this.m_progressBarConfig.periodSettings.isInitLoadAsc ? Object.keys(recordData[this.m_progressBarConfig.periodSettings.key])[0] : Object.keys(recordData[this.m_progressBarConfig.periodSettings.key])[Object.keys(recordData[this.m_progressBarConfig.periodSettings.key]).length];
            data = recordData[this.m_progressBarConfig.periodSettings.key][initPeriodKey];
        } else {
            data = recordData;
        }
        data = this.#_prepareChartData(data);

        if (dimensionsPreservedFlag) {
            this.updateProgressBarData(data);
        } else {
            this.reCreateProgressBars(data);
        }

        this.#_generatePeriodTimelineContainerDOM(recordData);
    };

    /**
     * This function updates the progress bar values when the categories are the same
     * 
     * @param {{name:<>, value: <>, color: <>}} data  Array of records used to generate the progress bars. 
    */
    updateProgressBarData = (data) => {
        this.#_calculateProgressBarTotal(data);

        data.forEach(record => {
            this.m_progressBarsRef.querySelector(`span.progressBar_CategoryValue[key='${record.key}']`).innerText = (this.#_processDisplayValue(record.value, this.m_progressBarPostValueSymbol));
            this.m_progressBarsRef.querySelector(`span.progressBarValue[key='${record.key}']`).style.width = (this.#_processBarValue(record.value));
        });
    };

    /**
     * This function can be used to replace the current progress bar data with new data categories and values
     * To be used when the categories are also updated
     * If the categories are the same and only values are being updated use the 'updateProgressBarData' function
     * 
     * @param {[{name:<>, value: <>, color: <>}]} data  Array of records used to generate the progress bars. 
    */
    reCreateProgressBars = (data) => {
        if (this.m_progressBarsRef) {
            this.m_progressBarsRef.remove();
        }

        if (this.m_parentRef.childElementCount !== 0) {
            throw new Error('Cannot recreate element as there is a child in the node already!');
        }

        this.#_calculateProgressBarTotal(data);

        this.createProgressBars(data);
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/

    /**
     * @param value 
     * @param {string} postValueSymbol Optional Symbol to be added after the value 
     * @returns {string}
     */
    #_processDisplayValue(value, postValueSymbol) {
        if (postValueSymbol === '%')
            value = Math.min(round((Number(value)/this.m_progressBarTotal) * 100, 1), 100);
        else
            value = round(Number(value), 1);

        return `${round(Number(value), 1)}${postValueSymbol ? postValueSymbol : ''}`;
    };

    #_processBarValue(value) {
        const calculatedValue = Math.min(round((Number(value)/this.m_progressBarTotal) * 100, 1), 100);
        return (!isNaN(calculatedValue) ? calculatedValue : 0) + '%';
    };

    /**
     * @param {[{name:<>, value: <>, color: <>}]} data  Array of records used to generate the progress bars. 
    */
    #_calculateProgressBarTotal(data) {
        let progressBarTotal = 0;
        data.forEach(record => {
            progressBarTotal += !isNaN(record.value) ? record.value : 0;
        });
        this.m_progressBarTotal = progressBarTotal;
    };

    /**
     * 
     * @param {{}} recordData   Data from the elasticSearch index, the values for each key will be added to the config.data structure which contains the format and other setting info required for the visual
     */
    #_prepareChartData = (recordData) => {
        const data = cloneDeep(this.m_progressBarConfig.data);
        data.forEach(obj => {
            obj['value'] = recordData[obj.key] ? Number(recordData[obj.key]) : 0;
        });
        return data;        
    };

    /**
     * Create the periodic data slider DOM element
     * @param {{}} recordData   Data from the elasticSearch index, the values for each key will be added to the config.data structure which contains the format and other setting info required for the visual
     */
    #_generatePeriodTimelineContainerDOM = (recordData) => {
        let inPlayMode = false;

        if (this.m_progressBarConfig.periodSettings && this.m_progressBarConfig.periodSettings.key) {
            // Delete previous periodic data slider DOM element before creating a new DOM element
            let periodTimelineContainerDOMRef = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}_periodTimelineContainer`);
            if (periodTimelineContainerDOMRef) {
                periodTimelineContainerDOMRef.remove();
            }

            let sliderStepSize = isFinite(100/(Object.keys(recordData[this.m_progressBarConfig.periodSettings.key]).length - 1)) ? (100/(Object.keys(recordData[this.m_progressBarConfig.periodSettings.key]).length - 1)) : 0; 
            let stepListOptions_HTML = ``;
            Object.keys(recordData[this.m_progressBarConfig.periodSettings.key]).forEach((dateValue, index) => {
                stepListOptions_HTML += `<option data-periodKey-value='${dateValue}' value='${index * sliderStepSize}' label='${new Date(Number(dateValue)).toLocaleDateString('en-US',{year:'2-digit'})}'></option>`;
            });

            const periodTimeline_HTML = `<div id='${this.m_progressBarConfig.DOM_ContainerId}_periodTimelineContainer' class='progressBar_periodTimelineContainer'>
                                            <button id='${this.m_progressBarConfig.DOM_ContainerId}_periodPlay' class='period_playPause' ${(sliderStepSize > 0) ? '' : 'disabled'}><i id='${this.m_progressBarConfig.DOM_ContainerId}_periodPlayIcon' class="fa-solid ${!inPlayMode ? 'fa-play' : 'fa-pause'}"></i></button>
                                            <span class='period_timeline_description'>${(this.m_progressBarConfig.periodSettings.description && this.m_progressBarConfig.periodSettings.description.length > 0) ? this.m_progressBarConfig.periodSettings.description : 'Play Timeline'}</span>
                                            <input id='${this.m_progressBarConfig.DOM_ContainerId}_input' value='${this.m_progressBarConfig.periodSettings.isInitLoadAsc ? 0 : 100}' ${(sliderStepSize > 0) ? '' : 'disabled'} type="range" min="0" max="100" step="${sliderStepSize}" list="${this.m_progressBarConfig.DOM_ContainerId}_steplist" class="progressBarPeriodSlider">
                                            <datalist id="${this.m_progressBarConfig.DOM_ContainerId}_steplist" class="period_steplist">
                                                ${stepListOptions_HTML}
                                            </datalist>
                                        </div>`;
            this.m_progressBarPeriodTimelineRef = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}`).insertAdjacentHTML("beforeend", `${periodTimeline_HTML}`);

            // Changing the slider mark position will trigger a change event which shows the selected periodic data
            const inputElement = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}_input`);

            // Set the initial active tick DOM element, based on the 'isInitLoadAsc' config
            let activeTick = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}_input`).list.options[this.m_progressBarConfig.periodSettings.isInitLoadAsc ? 0 : Object.keys(recordData[this.m_progressBarConfig.periodSettings.key]).length];
            if (activeTick) {
                activeTick.classList.add('period_steplist_active');
            }
            inputElement.addEventListener('change', (event) => {
                activeTick.classList.remove('period_steplist_active');

                const chartData = recordData[this.m_progressBarConfig.periodSettings.key][Array.from(event.target.list.options).find(option => { if(option.value === event.target.value) {activeTick=option; return true;} }).getAttribute('data-periodKey-value')];
                this.updateProgressBarData(this.#_prepareChartData(chartData));

                activeTick.classList.add('period_steplist_active');
            });

            const periodPlayButton = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}_periodPlay`);
            const periodPlayIcon = document.getElementById(`${this.m_progressBarConfig.DOM_ContainerId}_periodPlayIcon`);
            let timer, periodPlayIndex, periodPlayActiveTick;
            periodPlayButton.addEventListener('click', (event) => {
                const me = this;
                inPlayMode = !inPlayMode;

                if (inPlayMode) { // If state is in pause, and is to be changed to play
                    inputElement.disabled = true; // Disable a manual change in the periodTimeLine slider
                    periodPlayIcon.classList.replace('fa-play', 'fa-pause');

                    periodPlayActiveTick = activeTick;
                    periodPlayIndex = Object.keys(recordData[me.m_progressBarConfig.periodSettings.key]).indexOf(activeTick.getAttribute('data-periodKey-value'))

                    activeTick.classList.remove('period_steplist_active');

                    const moveToNextPeriodPlayTick = () => {
                        periodPlayActiveTick.classList.remove('period_steplist_active');

                        periodPlayIndex = (periodPlayIndex + 1) % (Object.keys(recordData[me.m_progressBarConfig.periodSettings.key]).length);

                        const chartData = recordData[me.m_progressBarConfig.periodSettings.key][Object.keys(recordData[me.m_progressBarConfig.periodSettings.key])[periodPlayIndex]];
                        me.updateProgressBarData(me.#_prepareChartData(chartData));
    
                        periodPlayActiveTick = inputElement.list.options[periodPlayIndex];
                        periodPlayActiveTick.classList.add('period_steplist_active');

                        inputElement.value = (periodPlayIndex * sliderStepSize);
                    };

                    moveToNextPeriodPlayTick();
                    clearInterval(timer);
                    timer = setInterval(() => {
                        moveToNextPeriodPlayTick();
                    }, 1000);
                } else if(!inPlayMode) { // If state is in play, and is to be changed to pause
                    periodPlayIcon.classList.replace('fa-pause', 'fa-play');
                    clearInterval(timer);
                    activeTick = periodPlayActiveTick;
                    inputElement.disabled = false;
                }
            });
        }
    };

}
