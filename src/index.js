import './styles/main.css';
import { AppController } from './js/controllers/AppController';
/** Start - Import templates (The template custom element defined, can be used in the HTML file once imported here) */
import './js/templates/RegionInfoBarTemplate';
import './js/templates/SDGScoreSettingsTemplate';
import './js/templates/SDGScoreSliderTemplate';
import './js/templates/custom/First_RegionInfoBarDiv';
/** End - Import templates */

let appController;
document.addEventListener('DOMContentLoaded', function () {
    appController = new AppController();
});

// To avoid memory leaks and end all events subscribed to and hooks
window.addEventListener('beforeunload', (event) => {
    appController.destroyer();
});