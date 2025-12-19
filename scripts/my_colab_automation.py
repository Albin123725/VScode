#!/usr/bin/env python3
"""
AUTOMATE YOUR MINECRAFT COLAB NOTEBOOK
This script will open your Colab notebook and run the Minecraft server
"""

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
import time
import random
import logging
import os
import pickle
import subprocess
import sys

# Setup logging
os.makedirs('/home/coder/logs', exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/coder/logs/colab_automation.log'),
        logging.StreamHandler()
    ]
)

class ColabMinecraftAutomator:
    def __init__(self):
        self.driver = None
        # CHANGE THIS TO YOUR COLAB NOTEBOOK URL
        self.colab_url = "https://colab.research.google.com/drive/1jckV8xUJSmLhhol6wZwVJzpybsimiRw1"
        self.cookies_file = '/home/coder/.cookies/google_cookies.pkl'
        self.setup_browser()
        
    def setup_browser(self):
        """Setup headless Chrome browser optimized for Colab"""
        chrome_options = Options()
        
        # Headless mode (no display needed)
        chrome_options.add_argument('--headless=new')
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        chrome_options.add_argument('--disable-gpu')
        chrome_options.add_argument('--window-size=1920,1080')
        
        # Bypass bot detection
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument('--disable-blink-features=AutomationControlled')
        
        # Performance optimizations
        prefs = {
            'profile.default_content_setting_values': {
                'images': 2,  # Block images to save RAM
                'javascript': 1,
                'plugins': 2,
            }
        }
        chrome_options.add_experimental_option('prefs', prefs)
        
        # User agent
        chrome_options.add_argument('--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            logging.info("✅ Browser started successfully")
            
            # Load saved cookies if they exist
            if os.path.exists(self.cookies_file):
                self.load_cookies()
                logging.info("✅ Cookies loaded from file")
                
            return True
        except Exception as e:
            logging.error(f"❌ Failed to start browser: {e}")
            return False
    
    def load_cookies(self):
        """Load saved cookies"""
        try:
            with open(self.cookies_file, 'rb') as f:
                cookies = pickle.load(f)
                for cookie in cookies:
                    try:
                        self.driver.add_cookie(cookie)
                    except:
                        pass
            return True
        except:
            return False
    
    def save_cookies(self):
        """Save cookies to file"""
        try:
            os.makedirs(os.path.dirname(self.cookies_file), exist_ok=True)
            with open(self.cookies_file, 'wb') as f:
                pickle.dump(self.driver.get_cookies(), f)
            logging.info("✅ Cookies saved")
            return True
        except:
            return False
    
    def is_logged_in(self):
        """Check if we're logged in to Google"""
        try:
            # Go to a Google page that requires login
            self.driver.get("https://myaccount.google.com/")
            time.sleep(2)
            
            # If we're redirected to login page, we're not logged in
            if "accounts.google.com" in self.driver.current_url:
                return False
            
            # Check for login indicators
            page_source = self.driver.page_source.lower()
            if "sign in" in page_source or "log in" in page_source:
                return False
                
            return True
        except:
            return False
    
    def open_colab(self):
        """Open Colab notebook"""
        logging.info("🌐 Opening Colab notebook...")
        self.driver.get(self.colab_url)
        time.sleep(5)
        
        # Check if we need to login
        if "accounts.google.com" in self.driver.current_url:
            logging.warning("⚠ Not logged in to Google")
            logging.warning("Please run manual_login.py first")
            return False
        
        logging.info("✅ Colab notebook loaded")
        return True
    
    def connect_to_runtime(self):
        """Connect to Colab runtime"""
        try:
            # Look for "Connect" button
            connect_xpaths = [
                "//span[contains(text(), 'Connect')]",
                "//button[contains(@aria-label, 'Connect')]",
                "//div[contains(text(), 'Connect')]"
            ]
            
            for xpath in connect_xpaths:
                try:
                    connect_buttons = self.driver.find_elements(By.XPATH, xpath)
                    if connect_buttons:
                        logging.info("🔗 Clicking Connect button...")
                        connect_buttons[0].click()
                        time.sleep(10)
                        break
                except:
                    continue
            
            # Check if connected
            time.sleep(3)
            page_text = self.driver.page_source.lower()
            if "connected" in page_text or "runtime" in page_text:
                logging.info("✅ Runtime connected")
                return True
            else:
                # Try to run all cells
                return self.run_all_cells()
                
        except Exception as e:
            logging.error(f"Error connecting: {e}")
            return False
    
    def run_all_cells(self):
        """Run all cells in the notebook"""
        try:
            # Look for "Run all" button
            run_all_xpaths = [
                "//button[contains(@aria-label, 'Run all')]",
                "//span[contains(text(), 'Run all')]",
                "//div[contains(text(), 'Run all')]"
            ]
            
            for xpath in run_all_xpaths:
                try:
                    run_all_buttons = self.driver.find_elements(By.XPATH, xpath)
                    if run_all_buttons:
                        logging.info("▶ Clicking 'Run all' button...")
                        run_all_buttons[0].click()
                        time.sleep(15)
                        logging.info("✅ All cells running")
                        return True
                except:
                    continue
            
            return False
        except Exception as e:
            logging.error(f"Error running cells: {e}")
            return False
    
    def take_screenshot(self, name):
        """Save screenshot for debugging"""
        try:
            timestamp = int(time.time())
            path = f"/home/coder/logs/{name}_{timestamp}.png"
            self.driver.save_screenshot(path)
            logging.debug(f"📸 Screenshot: {path}")
        except:
            pass
    
    def human_like_activity(self):
        """Simulate human activity to keep session alive"""
        activities = [
            self.scroll_randomly,
            self.press_arrow_keys,
            self.random_mouse_movement,
        ]
        
        try:
            activity = random.choice(activities)
            activity()
            logging.debug("👤 Simulated human activity")
        except:
            pass
    
    def scroll_randomly(self):
        """Scroll up or down randomly"""
        try:
            scroll_amount = random.choice([100, 200, 300, -100, -200])
            self.driver.execute_script(f"window.scrollBy(0, {scroll_amount});")
        except:
            pass
    
    def press_arrow_keys(self):
        """Press random arrow keys"""
        try:
            body = self.driver.find_element(By.TAG_NAME, 'body')
            keys = [Keys.ARROW_DOWN, Keys.ARROW_UP, Keys.PAGE_DOWN, Keys.PAGE_UP]
            body.send_keys(random.choice(keys))
        except:
            pass
    
    def random_mouse_movement(self):
        """Simulate mouse movement"""
        try:
            # Move mouse to random position
            x = random.randint(0, 1920)
            y = random.randint(0, 1080)
            self.driver.execute_script(f"window.scrollTo({x}, {y});")
        except:
            pass
    
    def keep_alive_loop(self):
        """Main loop to keep session alive"""
        logging.info("🛡️ Starting keep-alive protection...")
        
        last_activity = time.time()
        last_check = time.time()
        last_screenshot = time.time()
        
        while True:
            try:
                current_time = time.time()
                
                # Human activity every 1-3 minutes
                if current_time - last_activity > random.uniform(60, 180):
                    self.human_like_activity()
                    last_activity = current_time
                    logging.info(f"🕒 [{time.strftime('%H:%M:%S')}] Session active")
                
                # Check runtime every 5 minutes
                if current_time - last_check > 300:
                    if not self.check_runtime_status():
                        logging.warning("⚠ Runtime disconnected, reconnecting...")
                        self.connect_to_runtime()
                    last_check = current_time
                
                # Screenshot every 30 minutes
                if current_time - last_screenshot > 1800:
                    self.take_screenshot("periodic_check")
                    last_screenshot = current_time
                
                # Refresh page every 60-90 minutes (random)
                if random.random() < 0.001:  # ~1% chance each loop
                    logging.info("🔄 Refreshing page...")
                    self.driver.refresh()
                    time.sleep(8)
                    self.connect_to_runtime()
                
                time.sleep(10)  # Small delay between loops
                
            except KeyboardInterrupt:
                logging.info("🛑 Stopped by user")
                break
            except Exception as e:
                logging.error(f"❌ Error in keep-alive: {e}")
                self.recover()
    
    def check_runtime_status(self):
        """Check if runtime is still connected"""
        try:
            # Look for "Reconnect" button (indicates disconnection)
            reconnect_elements = self.driver.find_elements(By.XPATH, "//*[contains(text(), 'Reconnect')]")
            if reconnect_elements:
                return False
            
            # Check page for "Connected" text
            page_text = self.driver.page_source.lower()
            if "disconnected" in page_text:
                return False
                
            return True
        except:
            return False
    
    def recover(self):
        """Recover from errors"""
        logging.info("🔄 Attempting recovery...")
        try:
            if self.driver:
                self.driver.quit()
        except:
            pass
        
        time.sleep(10)
        
        # Restart browser
        if self.setup_browser():
            if self.open_colab():
                self.connect_to_runtime()
                logging.info("✅ Recovery successful")
                return True
        
        logging.error("❌ Recovery failed")
        return False
    
    def start(self):
        """Start the automation"""
        logging.info("="*60)
        logging.info("🚀 STARTING MINECRAFT COLAB AUTOMATION")
        logging.info("="*60)
        
        # Open Colab
        if not self.open_colab():
            logging.error("❌ Cannot open Colab")
            return False
        
        # Connect to runtime
        if not self.connect_to_runtime():
            logging.error("❌ Cannot connect to runtime")
            return False
        
        # Save cookies for next time
        self.save_cookies()
        
        logging.info("✅ Automation started successfully!")
        logging.info("💡 Minecraft server should be running in Colab")
        
        # Start keep-alive loop
        self.keep_alive_loop()

def main():
    """Main function with restart logic"""
    max_retries = 5
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            automator = ColabMinecraftAutomator()
            automator.start()
            retry_count = 0  # Reset on successful start
        except KeyboardInterrupt:
            logging.info("🛑 Manual shutdown requested")
            break
        except Exception as e:
            logging.error(f"💀 Fatal error: {e}")
            retry_count += 1
            wait_time = min(60, retry_count * 30)
            logging.info(f"🔄 Restarting in {wait_time} seconds... (Attempt {retry_count}/{max_retries})")
            time.sleep(wait_time)
    
    if retry_count >= max_retries:
        logging.error("❌ Maximum retries reached. Giving up.")

if __name__ == "__main__":
    main()
