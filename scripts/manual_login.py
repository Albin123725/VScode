#!/usr/bin/env python3
"""
ONE-TIME MANUAL LOGIN SCRIPT
Run this once to login to Google manually
"""

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import pickle
import os
import sys

def setup_browser():
    """Setup browser WITHOUT headless mode (so you can see it)"""
    chrome_options = Options()
    options = [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--window-size=1920,1080',
        '--disable-blink-features=AutomationControlled'
    ]
    
    for option in options:
        chrome_options.add_argument(option)
    
    # Explicitly NOT headless
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    
    return webdriver.Chrome(options=chrome_options)

def save_cookies(driver, filename):
    """Save cookies to file"""
    try:
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, 'wb') as f:
            pickle.dump(driver.get_cookies(), f)
        print(f"✅ Cookies saved to {filename}")
        return True
    except Exception as e:
        print(f"❌ Failed to save cookies: {e}")
        return False

def manual_login():
    """Perform manual login to Google"""
    print("\n" + "="*60)
    print("🔑 GOOGLE MANUAL LOGIN SETUP")
    print("="*60)
    print("This script will open Chrome where you can login to Google.")
    print("After login, cookies will be saved for automatic use.")
    print("="*60 + "\n")
    
    driver = None
    try:
        # Start browser
        print("🌐 Opening browser...")
        driver = setup_browser()
        
        # Go to Google login
        print("📝 Navigating to Google login...")
        driver.get("https://accounts.google.com")
        time.sleep(3)
        
        print("\n" + "="*60)
        print("MANUAL ACTION REQUIRED:")
        print("1. Login to your Google account in the browser window")
        print("2. Complete any 2FA if required")
        print("3. Wait until you see your Google account page")
        print("4. Come back here and press ENTER")
        print("="*60 + "\n")
        
        # Wait for user to press Enter
        input("Press ENTER after you've logged in successfully...")
        
        # Verify login by checking current URL
        current_url = driver.current_url
        print(f"Current URL: {current_url}")
        
        if "myaccount.google.com" in current_url or "drive.google.com" in current_url:
            print("✅ Detected successful login!")
        else:
            print("⚠ Warning: May not be logged in")
            response = input("Are you logged in? (y/n): ")
            if response.lower() != 'y':
                print("❌ Please try again")
                driver.quit()
                return False
        
        # Save cookies
        cookies_file = '/home/coder/.cookies/google_cookies.pkl'
        if save_cookies(driver, cookies_file):
            # Test cookies by loading them in a new session
            print("\n🧪 Testing saved cookies...")
            
            # Create a quick test to verify cookies work
            test_driver = setup_browser()
            test_driver.get("https://myaccount.google.com")
            
            # Load cookies
            if os.path.exists(cookies_file):
                with open(cookies_file, 'rb') as f:
                    cookies = pickle.load(f)
                    for cookie in cookies:
                        try:
                            test_driver.add_cookie(cookie)
                        except:
                            pass
                
                # Refresh to apply cookies
                test_driver.refresh()
                time.sleep(3)
                
                # Check if we're logged in
                if "myaccount.google.com" in test_driver.current_url:
                    print("✅ Cookies verified! They work correctly.")
                else:
                    print("⚠ Cookies may not work properly")
            
            test_driver.quit()
            
            print("\n" + "="*60)
            print("✅ SETUP COMPLETE!")
            print("="*60)
            print("You can now run the automated script.")
            print("Run: python3 ~/scripts/my_colab_automation.py")
            print("Or start it in screen: screen -dmS colab python3 ~/scripts/my_colab_automation.py")
            print("="*60)
            
            return True
        else:
            print("❌ Failed to save cookies")
            return False
            
    except Exception as e:
        print(f"❌ Error during manual login: {e}")
        return False
    finally:
        if driver:
            print("\n🔄 Closing browser...")
            driver.quit()

def quick_colab_test():
    """Quick test to verify Colab access"""
    print("\n🧪 Testing Colab access...")
    
    try:
        # Setup headless browser for test
        chrome_options = Options()
        chrome_options.add_argument('--headless=new')
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        
        driver = webdriver.Chrome(options=chrome_options)
        
        # Load cookies
        cookies_file = '/home/coder/.cookies/google_cookies.pkl'
        if os.path.exists(cookies_file):
            driver.get("https://colab.research.google.com")
            with open(cookies_file, 'rb') as f:
                cookies = pickle.load(f)
                for cookie in cookies:
                    try:
                        driver.add_cookie(cookie)
                    except:
                        pass
            
            driver.refresh()
            time.sleep(3)
            
            if "colab.research.google.com" in driver.current_url:
                print("✅ Colab access verified!")
                return True
            else:
                print("⚠ Could not access Colab")
                return False
        else:
            print("❌ No cookies found")
            return False
            
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False
    finally:
        try:
            driver.quit()
        except:
            pass

if __name__ == "__main__":
    print("="*70)
    print("GOOGLE LOGIN SETUP FOR MINECRAFT COLAB AUTOMATION")
    print("="*70)
    
    # Run manual login
    if manual_login():
        # Optional: Run quick test
        test = input("\nRun quick Colab access test? (y/n): ")
        if test.lower() == 'y':
            quick_colab_test()
    else:
        print("\n❌ Setup failed. Please try again.")
        sys.exit(1)
