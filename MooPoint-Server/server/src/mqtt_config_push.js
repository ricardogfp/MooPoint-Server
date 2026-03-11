const { logger } = require('./logger');

/**
 * MQTT Config Push Module
 * Publishes configuration updates to gateways for relay to trackers
 */

let mqttClient = null;

function init(client) {
  mqttClient = client;
  logger.info('MQTT Config Push module initialized');
}

/**
 * Publish config update to gateway for specific tracker
 * @param {number} gatewayId - Gateway node ID
 * @param {number} nodeId - Tracker node ID
 * @param {object} config - Configuration object
 * @param {number} configVersion - Config version number
 * @returns {Promise<void>}
 */
async function publishConfigUpdate(gatewayId, nodeId, config, configVersion) {
  if (!mqttClient) {
    throw new Error('MQTT client not initialized');
  }

  const topic = `moopoint/cmd/gateway/${gatewayId}/config_update`;
  const payload = {
    node_id: nodeId,
    config_version: configVersion,
    config: config,
    timestamp: Date.now(),
  };

  return new Promise((resolve, reject) => {
    mqttClient.publish(
      topic,
      JSON.stringify(payload),
      { qos: 1, retain: false },
      (err) => {
        if (err) {
          logger.error('Failed to publish config update', {
            gatewayId,
            nodeId,
            configVersion,
            error: err.message,
          });
          reject(err);
        } else {
          logger.info('Published config update', {
            gatewayId,
            nodeId,
            configVersion,
            topic,
          });
          resolve();
        }
      }
    );
  });
}

/**
 * Publish config update to multiple gateways for a tracker
 * @param {number[]} gatewayIds - Array of gateway node IDs
 * @param {number} nodeId - Tracker node ID
 * @param {object} config - Configuration object
 * @param {number} configVersion - Config version number
 * @returns {Promise<void[]>}
 */
async function publishConfigUpdateToGateways(gatewayIds, nodeId, config, configVersion) {
  const promises = gatewayIds.map((gatewayId) =>
    publishConfigUpdate(gatewayId, nodeId, config, configVersion)
  );
  return Promise.all(promises);
}

/**
 * Subscribe to config acknowledgement topic for a gateway
 * @param {number} gatewayId - Gateway node ID
 * @param {function} callback - Callback function (topic, message)
 */
function subscribeToConfigAck(gatewayId, callback) {
  if (!mqttClient) {
    throw new Error('MQTT client not initialized');
  }

  const topic = `moopoint/telemetry/gateway/${gatewayId}/config_ack`;
  
  mqttClient.subscribe(topic, { qos: 1 }, (err) => {
    if (err) {
      logger.error('Failed to subscribe to config ack topic', {
        gatewayId,
        topic,
        error: err.message,
      });
    } else {
      logger.info('Subscribed to config ack topic', { gatewayId, topic });
    }
  });

  mqttClient.on('message', (receivedTopic, message) => {
    if (receivedTopic === topic) {
      try {
        const payload = JSON.parse(message.toString());
        callback(receivedTopic, payload);
      } catch (err) {
        logger.error('Failed to parse config ack message', {
          topic: receivedTopic,
          error: err.message,
        });
      }
    }
  });
}

module.exports = {
  init,
  publishConfigUpdate,
  publishConfigUpdateToGateways,
  subscribeToConfigAck,
};
