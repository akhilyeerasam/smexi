import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { enums } from '../utilities/enums';
import { capitalize } from 'lodash';

export class MapModel {

    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    map;

    baseLayers = {};
    previousBaseLayerName; // Tracks the previous base layer map 'key' name stored in the object 'baseLayers'. Used for callback when switching between base map layers
    overlayLayers = {}; // All types of overlay classes will be maintained in this object for memory reference for ease of update operations
    controlLayers;
    legendLayers = {}; // All legend layers are maintained in this object
    
    constructor(initMapConfig) {
        this.loadMap(initMapConfig);
    }

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/

    // Initially load a simple map, based on the 'mapConfig' properties provided
    // Plotting and addon functionalities to the map can be added via other custom methods
    loadMap = (mapConfig) => {
        // Used to load and display tile layers on the map
        // Most tile servers require attribution, which you can set under `Layer`
        const defaultLayer = L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution:
                '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        });

        // The default layer to be first viewed on app load. Additional layers can be added via the 'addLayer' function
        mapConfig['layers'] = [defaultLayer];

        this.map = L.map(mapConfig.DOM_Id, mapConfig).setView([mapConfig.lat, mapConfig.lng], mapConfig.zoom);

        this.baseLayers = {
            [enums.baselayer_default]: defaultLayer
        };
        this.previousBaseLayerName = enums.baselayer_default;

        this.controlLayers = L.control.layers(this.baseLayers).addTo(this.map);

        // this.#_addMovableCircle();

        // this.addBaseLayer(enums.baselayer_transport, 'https://tileserver.memomaps.de/tilegen/{z}/{x}/{y}.png', 'https://memomaps.de/en/homepage/');
    };

    /** 
     * Function adds another map layer to the mapModel object
     * @param {string} layerName    name to be given to a key in the public variable 'baseLayers', which will help with quick access to the map layer info
     * @param {string} layerImgURL  the map layer link (.png.. file) will be provided here to load as an option
     * @param {string} layerLink    optional link to the provider of the map for copyright
     */
    addBaseLayer = (layerName, layerImgURL, layerLink) => {
        const baseMapLayer = L.tileLayer(layerImgURL, { 
            attribution: (layerLink ? `&copy; ${layerLink} Contributors` : '') 
        });

        this.controlLayers.addBaseLayer(baseMapLayer, layerName);
        this.baseLayers[layerName] = baseMapLayer;
    };

    switchBaseLayer = (layerName) => {
        // Only execute function if the layerNames are different
        // If function is executed for the same layer name, a flicker in the map will be noticable due to map reload
        if (this.previousBaseLayerName !== layerName) {
            this.map.removeLayer(this.baseLayers[this.previousBaseLayerName]);
            this.map.addLayer(this.baseLayers[layerName]);
            this.previousBaseLayerName = layerName;    
        }
    };

    /**
     * Function adds an overlay layer, which adds on to the base map layer. This overlay layer stores shapes, markers info. Enabling them to be toggled on/off the map view
     * @param {string} layerName                            name to be given to a key in the public variable 'overlayLayers', which will help with quick access to the layer info, which includes markers, shapes..
     * @param {string <overlay/featureGroup>} layerType     type of leaflet layer which stores the markers and shapes within it
     */
    addOverlayLayer = (layerName, layerType) => {
        switch(layerType) {
            case 'overlay': const overlay = L.layerGroup();
                            this.overlayLayers[layerName] = overlay;
                            //this.map.addLayer(overlay);
                            //this.controlLayers = L.control.layers(this.baseLayers, this.overlayLayers).addTo(this.map);
                            break;
            case 'featureGroup': const featureGroupLayer = L.featureGroup();
                                this.overlayLayers[layerName] = featureGroupLayer;
                                this.map.addLayer(featureGroupLayer);
                                break;
            default: console.error('Incorrect layerType!');
        }
    };

    /**
     * 
     * @param {string} layerName 
     * @param {boolean} deleteRefFlag boolean value, decides if the layers/shapes... inside this overlay layer should be removed permanently. If false, the shapes will be hidden from the view, but still be available for future recall
     */
    hideOverlayLayer = (layerName, deleteRefFlag) => {
        if (deleteRefFlag)
            this.overlayLayers[layerName].clearLayers();
        else
            this.map.removeLayer(this.overlayLayers[layerName]);
    };

    showOverlayLayer = (layerName) => {
        this.map.addLayer(this.overlayLayers[layerName]);
    };

    /**
     * 
     * @param {[{}]} plottingData           An array of records, which will be looped over to plot individually on the map
     * @param {string} geo_shapeKey         The plot data is stored in an object, this will store the string value of the key in the object which stores the plot geoinformation
     * @param {boolean} invertLngLat        If data is in LngLat format, below function converts it to LatLng format, which is the format for Leaflet
     * @param {{}} shapeOptions             An object which stores additional property info required for the shape being plotted
     * @param {string} overlayLayerName     Name of key in the public variable 'overlayLayers', which will store the quick access location shape info
     * @param {() => {}} onClickCallBack    An callback function, which will be called on click of the plotshape. E.g: Click on a polygon shape to drill down and visualise more information
     */
    plotMap = (plottingData, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack) => {
        plottingData.forEach(record => {
            this.plotShape(record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack);
        });
    };

    plotShape = (record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack) => {
        switch(record[geo_shapeKey].type) {
            case 'Polygon': this.plotPolygon(record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack);
                            break;
            case 'point':   this.plotPoint(record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack);
                            break;
        }
    };

    plotPolygon = (record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack) => {
        let plottingData = record[geo_shapeKey].coordinates;
        if (invertLngLat) {
            // If data is in LngLat format, below function converts it to LatLng format, which is the format for Leaflet
            plottingData = L.GeoJSON.coordsToLatLngs(plottingData, 1, L.GeoJSON.coordsToLatLng);
        }

        const addToLayer = this.overlayLayers[overlayLayerName];

        const polygon = L.polygon([plottingData], (shapeOptions ? shapeOptions : {})).addTo(addToLayer);
        if (onClickCallBack) {
            polygon.on('click', () => {
                onClickCallBack(record, geo_shapeKey, invertLngLat, plottingData);
            });
        }
    };

    plotPoint = (record, geo_shapeKey, invertLngLat, shapeOptions, overlayLayerName, onClickCallBack) => {
        let plottingData = record[geo_shapeKey].coordinates;
        if (invertLngLat) {
            // If data is in LngLat format, below function converts it to LatLng format, which is the format for Leaflet
            const [lng, lat] = plottingData;
            plottingData = new L.LatLng(lat, lng);
        }

        const addToLayer = this.overlayLayers[overlayLayerName];

        const styleString = (
            Object.entries(shapeOptions ? shapeOptions : {}).map(([k, v]) => `${k}:${v}`).join(';')
        );
          
        const customIcon = L.divIcon({
            className: 'map_marker_icon', // Add a custom class for styling
            html: `<i class="fas fa-map-marker-alt fa-2xl" style=${styleString}></i>`, // Font Awesome icon markup
            iconSize: [30, 30], // Size of the icon
            iconAnchor: [10, 30], // Anchor point of the icon (center bottom)
        });

        // let pointMarker = L.marker(plottingData).addTo(addToLayer);; //.bindPopup(title);
        let pointMarker = L.marker(plottingData, { icon: customIcon }).addTo(addToLayer);; //.bindPopup(title);

        if (onClickCallBack) {
            pointMarker.on('click', () => {
                onClickCallBack(record, geo_shapeKey, invertLngLat, plottingData);
            });
        }
    };

    /**
     * 
     * @param { {label: string, color: string, indicator?: string}[] } legendValues
     * @param { string } legendLayerName
     * @param { string } legendTitle
     */
    createLegend = (legendValues, legendLayerName, legendTitle) => {
        if (!this.legendLayers[legendLayerName]) {
            this.legendLayers[legendLayerName] = L.control({position: 'bottomright'});
    
            this.legendLayers[legendLayerName].onAdd = function (map) {
                let legendDiv = L.DomUtil.create('div', 'leafletInfo leafletLegend');
    
                legendDiv.innerHTML += `<h4>${legendTitle ? legendTitle : 'Legend'}</h4>`;
    
                legendValues.forEach(legendObj => {
                    switch (legendObj.indicator) {
                        case 'icon':    legendDiv.innerHTML += `<i class="fas fa-map-marker-alt" style="color: ${legendObj.color}; font-size: 16px"></i>`; // Font Awesome icon markup
                                        break;
                        default: legendDiv.innerHTML += `<i style="background: ${legendObj.color}"></i>`;
                    }
                    legendDiv.innerHTML += `<span>${capitalize(legendObj.label)}</span><br>`;
                });
    
                return legendDiv;
            };
    
            this.legendLayers[legendLayerName].addTo(this.map);
        }
    };

    removeLegend = (legendLayerName) => {
        if (this.legendLayers[legendLayerName]) {
            this.map.removeControl(this.legendLayers[legendLayerName]);
            delete this.legendLayers[legendLayerName];
        }
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/

    _addMovableCircle() {
        var circle = L.circle([49.4401, 7.7491], {
            color: 'red',
            fillColor: '#f03',
            fillOpacity: 0.5,
            radius: 500
        });

		// circle.editing.enable();
		//this.map.addLayer(circle);
        this.addOverlayLayer('circle_move', 'featureGroup');
        circle.addTo(this.overlayLayers['KL_landuse']);
        this.overlayLayers['KL_landuse'].bringToFront();

        const me = this;
        function trackCursor(evt) {
            circle.setLatLng(evt.latlng)
        }
        
        circle.on("mousedown", function() {
            me.map.dragging.disable()
            me.map.on("mousemove", trackCursor)
        });
        
        this.map.on("mouseup", function() {
            me.map.dragging.enable()
            me.map.off("mousemove", trackCursor)
        });
    };

}
