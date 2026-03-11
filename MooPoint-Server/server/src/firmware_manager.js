const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const { logger } = require('./logger');

const FIRMWARE_DIR = path.join(__dirname, '..', 'uploads', 'firmware');

// Ensure firmware directory exists
fs.mkdirSync(FIRMWARE_DIR, { recursive: true });

function calculateChecksum(filePath) {
  const hash = crypto.createHash('sha256');
  const data = fs.readFileSync(filePath);
  hash.update(data);
  return hash.digest('hex');
}

function validateHexFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    // Basic Intel HEX format validation
    for (const line of lines) {
      if (line.trim().length === 0) continue;
      if (!line.startsWith(':')) {
        return { valid: false, error: 'Invalid HEX format: lines must start with :' };
      }
    }
    
    return { valid: true };
  } catch (err) {
    return { valid: false, error: err.message };
  }
}

function generateDfuPackage(hexPath, zipPath) {
  try {
    // Note: adafruit-nrfutil is a Python tool, not npm package
    // We need to call it via command line
    // Device type 0x0052 is for nRF52840
    const cmd = `adafruit-nrfutil dfu genpkg --dev-type 0x0052 --application "${hexPath}" "${zipPath}"`;
    
    logger.info('Generating DFU package', { hexPath, zipPath, cmd });
    
    execSync(cmd, { stdio: 'inherit' });
    
    logger.info('DFU package generated successfully', { zipPath });
    return { success: true };
  } catch (err) {
    logger.error('Failed to generate DFU package', { error: err.message });
    return { success: false, error: err.message };
  }
}

function deleteFirmwareFiles(filenameHex, filenameZip) {
  try {
    const hexPath = path.join(FIRMWARE_DIR, filenameHex);
    const zipPath = path.join(FIRMWARE_DIR, filenameZip);
    
    if (fs.existsSync(hexPath)) {
      fs.unlinkSync(hexPath);
      logger.info('Deleted firmware hex file', { hexPath });
    }
    
    if (fs.existsSync(zipPath)) {
      fs.unlinkSync(zipPath);
      logger.info('Deleted firmware zip file', { zipPath });
    }
    
    return { success: true };
  } catch (err) {
    logger.error('Failed to delete firmware files', { error: err.message });
    return { success: false, error: err.message };
  }
}

module.exports = {
  FIRMWARE_DIR,
  calculateChecksum,
  validateHexFile,
  generateDfuPackage,
  deleteFirmwareFiles,
};
