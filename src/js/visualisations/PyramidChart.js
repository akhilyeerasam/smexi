import * as d3 from 'd3';
import { assign, cloneDeep } from 'lodash';

export class PyramidChart {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    m_pyramidChartRef;
    m_pyramidChartLegendRef;
    m_pyramidChartPeriodTimelineRef;

    m_pyramidChartConfig;
    m_pyramidChartData = [];

    settings = {
        width: 200,
        height: 200,
        marginTop: 20,
        marginRight: 20,
        marginBottom: 24,
        marginLeft: 20,
        marginMiddle: 28
    };

    /**
     * @param {{}} pyramidChartConfig                                                               PyramidChart config, refer to the config files for all possible keys available under this object
     * @param {[{groupCategory: string, leftCategory: number, rightCategory: number}]} init_data    Array of records used to generate the pyramid chart. {name:<>, value: <>, color: <>}, structure of the object in the array to be accepted
    */
    constructor(pyramidChartConfig, init_data) {
        this.m_pyramidChartConfig = pyramidChartConfig;

        this.m_parentRef = document.getElementById(this.m_pyramidChartConfig.DOM_ContainerId);

        assign(this.settings, this.m_pyramidChartConfig.visual_settings);

        if (init_data && init_data.length > 0) {
            this.createPyramidChart(init_data);
        } else {
            this.createPyramidChart([{ groupCategory: '-', leftCategory: 0, rightCategory: 0 },]);
        }
    }

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/

    createPyramidChart = (data) => {
        const me = this;
        // the width of each side of the chart
        const regionWidth = ((this.settings.width / 2) - this.settings.marginMiddle);

        // these are the x-coordinates of the y-axes
        const pointA = regionWidth, pointB = this.settings.width - regionWidth;        

        // CREATE A FUNCTION FOR RETURNING THE PERCENTAGE
        const percentage = function (d, key) { return d[key] / (d['leftCategory'] + d['rightCategory']); };

        const pyramidChartContainerId = `pyramidChartRef_${Date.now()}_${this.m_parentRef.id}`;
        this.m_parentRef.insertAdjacentHTML("beforeend", `<div id='${pyramidChartContainerId}'></div>`);
        this.m_pyramidChartRef = document.getElementById(pyramidChartContainerId);

        // CREATE SVG
        const svg = d3.select(`#${pyramidChartContainerId}`).append('svg')
            .attr('width', '100%')
            .attr('viewBox','0 0 ' + Math.min((this.settings.marginLeft + this.settings.width + this.settings.marginRight), (this.settings.marginTop + this.settings.height + this.settings.marginBottom)) + ' '+ Math.min((this.settings.marginLeft + this.settings.width + this.settings.marginRight), (this.settings.marginTop + this.settings.height + this.settings.marginBottom)) )
            .attr("class", "pyramidChartContainer")
            // ADD A GROUP FOR THE SPACE WITHIN THE MARGINS
            .append('g')
            .attr('transform', `translate(${this.settings.marginLeft}, ${this.settings.marginTop})`);

        // find the maximum data value on either side
        // since this will be shared by both of the x-axes
        const maxValue = Math.max(
            d3.max(data, function (d) { return percentage(d, 'leftCategory'); }),
            d3.max(data, function (d) { return percentage(d, 'rightCategory'); })
        );

        // SET UP SCALES

        // the xScale goes from 0 to the width of a region
        //  it will be reversed for the left x-axis
        me.xScale = d3.scaleLinear()
            .domain([0, maxValue])
            .range([0, regionWidth])
            .nice();

        const xScaleLeft = d3.scaleLinear()
            .domain([0, maxValue])
            .range([regionWidth, 0]);

        const xScaleRight = d3.scaleLinear()
            .domain([0, maxValue])
            .range([0, regionWidth]);

        me.yScale = d3.scaleBand()
            .domain(data.map(function (d) { return d['groupCategory']; }))
            .range([this.settings.height, 0])
            .padding(0.1);

        // SET UP AXES
        const yAxisLeft = d3.axisRight() // Reversed for left-oriented y-axis
            .scale(me.yScale)
            .tickSize(4)
            .tickPadding(this.settings.marginMiddle - 4);

        const yAxisRight = d3.axisLeft()
            .scale(me.yScale)
            .tickSize(4)
            .tickFormat('');

        const xAxisRight = d3.axisBottom()
            .scale(me.xScale)
            .ticks(Math.max((this.settings.marginLeft + (this.settings.width/2) + this.settings.marginRight)/50, 2))
            .tickFormat(d3.format('.0%'));

        const xAxisLeft = d3.axisBottom()
            .scale(xScaleLeft) // Reversed for left-oriented x-axis
            .ticks(Math.max((this.settings.marginLeft + (this.settings.width/2) + this.settings.marginRight)/50, 2))
            .tickFormat(d3.format('.0%'));

        // MAKE GROUPS FOR EACH SIDE OF CHART
        // scale(-1,1) is used to reverse the left side so the bars grow left instead of right
        this.leftBarGroup = svg.append('g')
            .attr('transform', `translate(${pointA}, 0) scale(-1,1)`);
        this.rightBarGroup = svg.append('g')
            .attr('transform', `translate(${pointB}, 0)`);

        // DRAW AXES
        svg.append('g')
            .attr('class', 'axis y left')
            .attr('transform', `translate(${pointA}, 0)`)
            .call(yAxisLeft)
            .selectAll('text')
            .style('text-anchor', 'middle');

        svg.append('g')
            .attr('class', 'axis y right')
            .attr('transform', `translate(${pointB}, 0)`)
            .call(yAxisRight);

        svg.append('g')
            .attr('class', 'axis x left')
            .attr('transform', `translate(0, ${this.settings.height})`)
            .call(xAxisLeft);

        svg.append('g')
            .attr('class', 'axis x right')
            .attr('transform', `translate(${pointB}, ${this.settings.height})`)
            .call(xAxisRight);

        const tooltip = d3.select("#visualTooltip");

        // DRAW BARS
        this.leftBarGroup.selectAll('.bar.left')
            .data(data)
            .enter().append('rect')
            .attr('class', 'bar left')
            .attr('x', 0)
            .attr('y', function (d) { return me.yScale(d['groupCategory']); })
            .attr('width', function (d) { return me.xScale(percentage(d, 'leftCategory')); })
            .attr('height', me.yScale.bandwidth())
            .attr("fill", (me.m_pyramidChartConfig.dataKeys.leftCategory.color) ? me.m_pyramidChartConfig.dataKeys.leftCategory.color : 'black')
            .on("mouseover", (event, d) => {
                tooltip.style("display", "block");
                tooltip.html(`${d['leftCategory']}`) // Customize the tooltip content as needed
                    .style("left", event.pageX + 10 + "px") // Adjust the position
                    .style("top", event.pageY - 10 + "px");
            })
            .on("mouseout", () => {
                tooltip.style("display", "none");
            });

        this.rightBarGroup.selectAll('.bar.right')
            .data(data)
            .enter().append('rect')
            .attr('class', 'bar right')
            .attr('x', 0)
            .attr('y', function (d) { return me.yScale(d['groupCategory']); })
            .attr('width', function (d) { return me.xScale(percentage(d, 'rightCategory')); })
            .attr('height', me.yScale.bandwidth())
            .attr("fill", (me.m_pyramidChartConfig.dataKeys.rightCategory.color) ? me.m_pyramidChartConfig.dataKeys.rightCategory.color : 'black')
            .on("mouseover", (event, d) => {
                tooltip.style("display", "block");
                tooltip.html(`${d['rightCategory']}`) // Customize the tooltip content as needed
                    .style("left", event.pageX + 10 + "px") // Adjust the position
                    .style("top", event.pageY - 10 + "px");
            })
            .on("mouseout", () => {
                tooltip.style("display", "none");
            });

        if (!this.settings.hideVisualLegend) {
            this.updateChartLegend(data, pyramidChartContainerId);
        }
    };

    updateVisual = (data) => {
        this.m_pyramidChartData = this.#_prepareChartData(data);
        this.reCreatePyramidChart(this.m_pyramidChartData);
    };

    reCreatePyramidChart = (data) => {
        if (this.m_pyramidChartRef) {
            this.m_pyramidChartRef.remove();
        }

        this.createPyramidChart(data);
    };

    /**
     * Function updates only the chart legend values, making it useful for use when a filter is applied on the categories
     * @param {*} data
     */
    updateChartLegend = (data, pyramidChartContainerId) => {
        const legendArray = [
            { labelName: this.m_pyramidChartConfig.dataKeys.leftCategory.name, color: this.m_pyramidChartConfig.dataKeys.leftCategory.color },
            { labelName: this.m_pyramidChartConfig.dataKeys.rightCategory.name, color: this.m_pyramidChartConfig.dataKeys.rightCategory.color }
        ];

        // The visual legends are stored in another svg element for ease for maintainance
        this.m_pyramidChartLegendRef = d3.select(`#${pyramidChartContainerId}`)
                .append("svg")
                .attr("width", '100%')
                .attr("height", '50px')
                .attr("class", "pyramidChartLegendContainer");

        const legend = this.m_pyramidChartLegendRef.selectAll(".pyramidChartLegendContainer")
            .data(legendArray)
            .enter()
            .append("g")
            .attr("transform", (d, i) => "translate(" + (i % 2 * 150 + 10) + "," + (Math.floor(i / 2) * 20 + 10) + ")")
            .attr("class", "pyramidChartLegend");

        legend.append("rect")
            .attr("width", 10)
            .attr("height", 10)
            .style("fill", (d) => d.color ? d.color : 'black'); // Set the color

        legend.append("text")
            .attr("y", 10)
            .attr("x", 11)
            .attr("class", "pyramidChartLegend_Text")
            .text(d => d.labelName);
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    /**
     * 
     * @param {{}} recordData   Data from the elasticSearch index, the values for each key will be added to the config.data structure which contains the format and other setting info required for the visual
     */
    #_prepareChartData = (recordData) => {
        let data = [];
        if (this.m_pyramidChartConfig && this.m_pyramidChartConfig.periodSettings) {
            const dataKeys = this.m_pyramidChartConfig.dataKeys;
            for (const periodKey in recordData[this.m_pyramidChartConfig.periodSettings.key]) {
                const recordData_period = recordData[this.m_pyramidChartConfig.periodSettings.key][periodKey];
                data.push({
                    leftCategory: recordData_period[dataKeys.leftCategory.key] ? Number(recordData_period[dataKeys.leftCategory.key]) : 0, 
                    rightCategory: recordData_period[dataKeys.rightCategory.key] ? Number(recordData_period[dataKeys.rightCategory.key]) : 0, 
                    groupCategory: dataKeys.groupCategory.processText ? dataKeys.groupCategory.processText(recordData_period, periodKey) : recordData_period[dataKeys.groupCategory.key]
                });
            }
        } else {
            data = recordData;
        }

        return data;        
    };

}
