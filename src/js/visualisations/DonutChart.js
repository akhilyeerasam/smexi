import * as d3 from 'd3';
import { assign, cloneDeep } from 'lodash';

export class DonutChart {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    m_donutChartRef;
    m_donutChartLegendRef;
    m_donutArcRef;
    m_donutChartArcPathsRef;
    m_donutChartTextInMiddleRef; // Optional text in the middle of the chart reference can be used
    m_donutChartPeriodTimelineRef;

    m_donutChartConfig;
    m_donutChartData = [];

    settings = {
        hideVisualLegend: false,
        duration: 500,
        width: 200,
        height: 200,
        innerRadiusMultiple: 0.4
    };

    /**
     * @param {{}} donutChartConfig                                         DonutChart config, refer to the config files for all possible keys available under this object
     * @param {{name: string, value: number, color: string}} init_data      Array of records used to generate the donut chart. {name:<>, value: <>, color: <>}, structure of the object in the array to be accepted
    */
    constructor(donutChartConfig, init_data) {
        this.#_bindFunctionsToCurrentContext();

        this.m_donutChartConfig = donutChartConfig;

        assign(this.settings, this.m_donutChartConfig.visual_settings);
        this.radius = Math.floor(Math.min(this.settings.width / 2, this.settings.height / 2) * 0.9);

        this.init();

        if (init_data && init_data.length > 0) {
            this.updateVisual(init_data);
        } else {
            this.updateChartData([{ value: 1, color: 'gray', name: '-' }]);
        }
    }

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/
    // The init function creates the DOM references required for the donut chart visual
    init = () => {
        this.m_donutChartRef = d3.pie()
            .sort(null)
            .value(function (d) {
                return d['value'] ? d['value'] : 0;
            });
        this.m_donutArcRef = d3.arc()
            .innerRadius(this.radius * this.settings.innerRadiusMultiple)
            .outerRadius(this.radius);

        // Create the SVG container to store the visualisation
        const svg = d3.select(`#${this.m_donutChartConfig.DOM_ContainerId}`)
            .append("svg")
            .attr("width", '100%')
            .attr("height", this.height)
            .attr('viewBox','0 0 ' + Math.min(this.settings.width, this.settings.height) + ' '+ Math.min(this.settings.width, this.settings.height) )
            .attr("class", "donutChartContainer");

        const donutChartArcPaths = svg.append("g")
            .attr("class", "donutChartArcPaths")
            .attr("transform", "translate(" + (this.settings.width / 2) + "," + (this.settings.height / 2) + ")");

        this.m_donutChartTextInMiddleRef = donutChartArcPaths.append("svg:text")
                                                    .attr("dy", ".35em")
                                                    .attr("text-anchor", "middle")
                                                    .text("");

        this.m_donutChartArcPathsRef = donutChartArcPaths.selectAll("path");

        if (!this.settings.hideVisualLegend) {
            // The visual legends are stored in another svg element for ease for maintainance
            this.m_donutChartLegendRef = d3.select(`#${this.m_donutChartConfig.DOM_ContainerId}`)
                .append("svg")
                .attr("width", '100%')
                .attr("class", "donutChartLegendContainer");
        }

        // A slider is created if periodic data exists
        this.#_generatePeriodTimelineContainerDOM({[this.m_donutChartConfig.periodSettings ? this.m_donutChartConfig.periodSettings.key : undefined]: []});
    };

    updateVisual = (recordData, preservePreviousData) => {
        let data;
        if (this.m_donutChartConfig && this.m_donutChartConfig.periodSettings) {
            // The 'initPeriodKey', obtains the first time period to be displayed initially. Either an ascending/decending value of all possible time periods, as defined from the config
            const initPeriodKey = this.m_donutChartConfig.periodSettings.isInitLoadAsc ? Object.keys(recordData[this.m_donutChartConfig.periodSettings.key])[0] : Object.keys(recordData[this.m_donutChartConfig.periodSettings.key])[Object.keys(recordData[this.m_donutChartConfig.periodSettings.key]).length];
            data = recordData[this.m_donutChartConfig.periodSettings.key][initPeriodKey];
        } else {
            data = recordData;
        }
        data = this.#_prepareChartData(data);

        // When condition evaluates to true, it is used to replace the dataset
        // When condition evaluates to false, it is skipped and used when the legend filtering is done on the visualisation 
        if (!preservePreviousData) {
            this.m_donutChartData = data;

            // Remove the filter selections from the previous dataset view, through leftover DOM modifications
            Array.from(document.getElementsByClassName("donutChartLegend_HideOption")).forEach(function(el) { 
                el.classList.remove('donutChartLegend_HideOption');
            });
        }

        this.updateChartData(data);
        if (!this.settings.hideVisualLegend) {
            this.updateChartLegend(data);
        }

        this.#_generatePeriodTimelineContainerDOM(recordData);
    };

    /**
     * Function updates only the donut chart arcs with new values
     * @param {*} data 
     */
    updateChartData = (data) => {
        const me = this;
        this.m_donutChartArcPathsRef = this.m_donutChartArcPathsRef.data(this.m_donutChartRef(data), d => d.data.name);

        this.m_donutChartArcPathsRef.exit().remove();

        const tooltip = d3.select("#visualTooltip");

        this.m_donutChartArcPathsRef = this.m_donutChartArcPathsRef.enter()
            .append("path")
            .attr("stroke", "white")
            .attr("stroke-width", 0.8)
            .attr("fill", function (d, i) {
                return d.data.color;
            })
            .attr("d", me.m_donutArcRef)
            .merge(this.m_donutChartArcPathsRef)
            .on("mouseover", (event, d) => {
                tooltip.style("display", "block");
                tooltip.html(`${d.data.value}`) // Customize the tooltip content as needed
                    .style("left", event.pageX + 10 + "px") // Adjust the position
                    .style("top", event.pageY - 10 + "px");
            })
            .on("mouseout", () => {
                tooltip.style("display", "none");
            });

        this.m_donutChartArcPathsRef.transition()
            .duration(this.duration)
            .attrTween("d", this._arcTween);

        if (this.settings.textInMiddle) {
            this.m_donutChartTextInMiddleRef._groups[0][0].textContent = this.settings.textInMiddle(data);
        }
    };

    /**
     * Function updates only the chart legend values, making it useful for use when a filter is applied on the categories
     * @param {*} data 
     */
    updateChartLegend = (data) => {
        const legendG = this.m_donutChartLegendRef.selectAll(".donutChartLegendContainer")
            .data(this.m_donutChartRef(data), function (d) {
                return d.data.name;
            })

        const legendEnter = legendG.enter().append("g")
            .attr("transform", (d,i) => "translate(" + (i % 2 * 150 + 10) + "," + (Math.floor(i / 2) * 20 + 10) + ")")
            .attr("class", "donutChartLegend")
            .on('click', (e, d) => {
                if (e.target.classList.contains('donutChartLegend_HideOption'))
                    e.target.classList.remove('donutChartLegend_HideOption');
                else
                    e.target.classList.add('donutChartLegend_HideOption');

                const legendCategoriesToHide = Array.prototype.map.call(document.getElementsByClassName("donutChartLegend_HideOption"), (record) => record.__data__.data.key);

                const updatedData = this.m_donutChartData.map(record => {
                    if (legendCategoriesToHide.includes(record.key))
                        return {...record, value: 0};
                    return record;
                });
                this.updateChartData(updatedData);
            });

        legendG.exit().remove();

        legendEnter.append("rect")
            .attr("width", 10)
            .attr("height", 10)
            .attr("fill", (d,i) => d.data.color);

        legendEnter.append("text")
            .attr("y", 10)
            .attr("x", 11)
            .attr("class", "donutChartLegend_Text")
            .text(d => d.data.name);
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    /**
     * 
     * @param {{}} recordData   Data from the elasticSearch index, the values for each key will be added to the config.data structure which contains the format and other setting info required for the visual
     */
    #_prepareChartData = (recordData) => {
        const data = cloneDeep(this.m_donutChartConfig.data);
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

        if (this.m_donutChartConfig.periodSettings && this.m_donutChartConfig.periodSettings.key) {
            // Delete previous periodic data slider DOM element before creating a new DOM element
            let periodTimelineContainerDOMRef = document.getElementById(`${this.m_donutChartConfig.DOM_ContainerId}_periodTimelineContainer`);
            if (periodTimelineContainerDOMRef) {
                periodTimelineContainerDOMRef.remove();
            }
    
            let sliderStepSize = isFinite(100/(Object.keys(recordData[this.m_donutChartConfig.periodSettings.key]).length - 1)) ? (100/(Object.keys(recordData[this.m_donutChartConfig.periodSettings.key]).length - 1)) : 0; 
            let stepListOptions_HTML = ``;
            Object.keys(recordData[this.m_donutChartConfig.periodSettings.key]).forEach((dateValue, index) => {
                stepListOptions_HTML += `<option data-periodKey-value='${dateValue}' value='${index * sliderStepSize}' label='${new Date(Number(dateValue)).toLocaleDateString('en-US',{year:'2-digit'})}'></option>`;
            });

            const periodTimeline_HTML = `<div id='${this.m_donutChartConfig.DOM_ContainerId}_periodTimelineContainer'>
                                            <button id='${this.m_donutChartConfig.DOM_ContainerId}_periodPlay' class='period_playPause' ${(sliderStepSize > 0) ? '' : 'disabled'}><i id='${this.m_donutChartConfig.DOM_ContainerId}_periodPlayIcon' class="fa-solid ${!inPlayMode ? 'fa-play' : 'fa-pause'}"></i></button>
                                            <span class='period_timeline_description'>${(this.m_donutChartConfig.periodSettings.description && this.m_donutChartConfig.periodSettings.description.length > 0) ? this.m_donutChartConfig.periodSettings.description : 'Play Timeline'}</span>
                                            <input id='${this.m_donutChartConfig.DOM_ContainerId}_input' value='${this.m_donutChartConfig.periodSettings.isInitLoadAsc ? 0 : 100}' ${(sliderStepSize > 0) ? '' : 'disabled'} type="range" min="0" max="100" step="${sliderStepSize}" list="${this.m_donutChartConfig.DOM_ContainerId}_steplist" class="donutChartPeriodSlider">
                                            <datalist id="${this.m_donutChartConfig.DOM_ContainerId}_steplist" class="period_steplist">
                                                ${stepListOptions_HTML}
                                            </datalist>
                                        </div>`;
            this.m_donutChartPeriodTimelineRef = document.getElementById(`${this.m_donutChartConfig.DOM_ContainerId}`).insertAdjacentHTML("beforeend", `${periodTimeline_HTML}`);

            // Changing the slider mark position will trigger a change event which shows the selected periodic data
            const inputElement = document.getElementById(`${this.m_donutChartConfig.DOM_ContainerId}_input`);

            // Set the initial active tick DOM element, based on the 'isInitLoadAsc' config
            let activeTick = inputElement.list.options[this.m_donutChartConfig.periodSettings.isInitLoadAsc ? 0 : Object.keys(recordData[this.m_donutChartConfig.periodSettings.key]).length];
            if (activeTick) {
                activeTick.classList.add('period_steplist_active');
            }

            // Change in tick value in the periodTimeLine container DOM element
            inputElement.addEventListener('change', (event) => {
                activeTick.classList.remove('period_steplist_active');

                const chartData = recordData[this.m_donutChartConfig.periodSettings.key][Array.from(event.target.list.options).find(option => { if(option.value === event.target.value) {activeTick=option; return true;} }).getAttribute('data-periodKey-value')];
                this.updateChartData(this.#_prepareChartData(chartData));
                
                activeTick.classList.add('period_steplist_active');
            });

            const periodPlayButton = document.getElementById(`${this.m_donutChartConfig.DOM_ContainerId}_periodPlay`);
            const periodPlayIcon = document.getElementById(`${this.m_donutChartConfig.DOM_ContainerId}_periodPlayIcon`);
            let timer, periodPlayIndex, periodPlayActiveTick;
            periodPlayButton.addEventListener('click', (event) => {
                const me = this;
                inPlayMode = !inPlayMode;

                if (inPlayMode) { // If state is in pause, and is to be changed to play
                    inputElement.disabled = true; // Disable a manual change in the periodTimeLine slider
                    periodPlayIcon.classList.replace('fa-play', 'fa-pause');

                    periodPlayActiveTick = activeTick;
                    periodPlayIndex = Object.keys(recordData[me.m_donutChartConfig.periodSettings.key]).indexOf(activeTick.getAttribute('data-periodKey-value'))

                    activeTick.classList.remove('period_steplist_active');

                    const moveToNextPeriodPlayTick = () => {
                        periodPlayActiveTick.classList.remove('period_steplist_active');

                        periodPlayIndex = (periodPlayIndex + 1) % (Object.keys(recordData[me.m_donutChartConfig.periodSettings.key]).length);

                        const chartData = recordData[me.m_donutChartConfig.periodSettings.key][Object.keys(recordData[me.m_donutChartConfig.periodSettings.key])[periodPlayIndex]];
                        me.updateChartData(me.#_prepareChartData(chartData));
    
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

    #_arcTween = (newData) => {
        const i = d3.interpolate(this.current || {}, newData);
        this.current = i(0);
        return function (t) {
            return this.m_donutArcRef(i(t));
        }.bind(this);
    };

    #_bindFunctionsToCurrentContext() {
        this._arcTween = this.#_arcTween.bind(this); // '#_arcTween' function is passed as a parameter to function 'updateChartData'. This will allow the 'this' context to be maintained in current class
    };

}
