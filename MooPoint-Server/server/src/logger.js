const fs = require('fs');
const path = require('path');
const winston = require('winston');

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

const LOG_DIR = process.env.LOG_DIR || path.join(process.cwd(), 'logs');
ensureDir(LOG_DIR);

const LOG_FILE = process.env.LOG_FILE || path.join(LOG_DIR, 'app.log');

const SENSITIVE_KEYS = new Set(['cookie', 'authorization', 'set-cookie', 'password', 'device_key']);

function maskSensitiveFields(obj, depth = 0) {
  if (depth > 8 || obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map((item) => maskSensitiveFields(item, depth + 1));
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    result[key] = SENSITIVE_KEYS.has(key.toLowerCase()) ? '[REDACTED]' : maskSensitiveFields(value, depth + 1);
  }
  return result;
}

const maskFormat = winston.format((info) => {
  const masked = maskSensitiveFields(info);
  return Object.assign(info, masked);
})();

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    maskFormat,
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: LOG_FILE,
      maxsize: 5 * 1024 * 1024,
      maxFiles: 5
    }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.timestamp(),
        winston.format.printf((info) => {
          const { timestamp, level, message, ...rest } = info;
          const meta = Object.keys(rest).length ? ` ${JSON.stringify(rest)}` : '';
          return `${timestamp} ${level}: ${message}${meta}`;
        })
      )
    })
  ]
});

function setLogLevel(level) {
  logger.level = level;
  for (const t of logger.transports) {
    t.level = level;
  }
}

module.exports = {
  logger,
  LOG_FILE,
  setLogLevel
};
