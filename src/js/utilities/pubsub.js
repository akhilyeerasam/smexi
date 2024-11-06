// The PubSub variable will be used for Publisher-Subscriber data communication (Furthur reading can be done online for the concept)
// Maintained in a variable opposed to a Class-instantiated object to allow global access throughout project scope

const PubSub = (function () {
    const subscribers = {};

    return {
        subscribe: function (eventName, callback) {
            if (!subscribers[eventName]) {
                subscribers[eventName] = [];
            }
            subscribers[eventName].push(callback);
        },

        publish: function (eventName, data) {
            if (subscribers[eventName]) {
                subscribers[eventName].forEach(callback => callback(data));
            }
        },

        unsubscribe: function (eventName) {
            if (subscribers[eventName]) {
                delete subscribers[eventName];
            }
        },

        unsubscribeAll: function() {
            Object.keys(subscribers).forEach(eventName => {
                delete subscribers[eventName];
            });
        }
    };
})();

export default PubSub;