// The default app settings/values will be controlled from this variable
export const appSetting = {
    elasticsearchQuerySize: 5000, // Default size value when elasticsearch query is made to any index if not overwritten
    progressBarColor: 'black', // Default color to set progress bar, if no value is provided
};

export let sdgScoreSetting = { // Declared as 'let', as the settings update will be triggered to these values/memory location which are referenced throughout the app
    regionSettings: {
        sizeRangeSlider: {
            min: 1,
            max: 100
        },
        idealSize: 50 // Size is in acres as per calculation function used, defined as the minimum size upon which calculations for livability/sustainability will be performed
    },

    educationScoreSettings: {
        countRangeSlider: {
            min: 1,
            max: 18
        },
        idealCounts: {
            'Expected Years of Schooling': 18,
            'Mean Years of Schooling': 15
        }
    },

    amenitiesScoreSettings: {
        countRangeSlider: {
            min: 1,
            max: 10
        },
        idealCounts: { // value is defined as the number of amenities located in an area of the baseline sizes
            'Pharmacy': 3, // Keys used MUST be same as value for 'amenityName' key, under regionInfoBarConfig!
            'Grocery': 1
        } // value is defined as the number of amenities located in an area of the baseline sizes
    },

    transportScoreSettings: {
        countRangeSlider: {
            min: 1,
            max: 20
        },
        idealCounts: {
            'bus': 3, // Keys used MUST be same as value for 'OSMRouteValue' key, under regionInfoBarConfig!
            'train': 2
        }
    },

    landuseScoreSettings: {
        countRangeSlider: {
            min: 0,
            max: 100
        },
        idealCounts: {
            'building': 10, // Keys used MUST be same as the key 'OSMTagsProperties' under regionInfoBarConfig!
            'amenity': 10,
            'leisure': 10,
            'residential': 10,
            'highway': 10,
            'natural': 10,
            'waterway': 10,
            'power': 10,
            'other': 10,
            'landuse': 10
        }

    }
};

export const regionInfoBarSettings = {
    defaultRegionInfoBarSettings: { concatId: "", color: 'blue' },
    compareRegionInfoBarSettings: { concatId: "_compare", color: 'red' }
}
