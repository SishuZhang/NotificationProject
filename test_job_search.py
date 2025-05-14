#!/usr/bin/env python
"""
Test script to search Indeed jobs and display results
Usage: python test_job_search.py "Job Title" "Location"
"""

import sys
import json
import requests
from bs4 import BeautifulSoup
import urllib.parse
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Sample job data for demo mode
SAMPLE_JOBS = {
    "Data Scientist": [
        {
            "title": "Senior Data Scientist",
            "company": "Tech Innovations Inc",
            "location": "New York, NY (Remote)",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=abc123"
        },
        {
            "title": "Data Scientist, Machine Learning",
            "company": "DataCorp Analytics",
            "location": "New York, NY",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=def456"
        },
        {
            "title": "AI/ML Data Scientist",
            "company": "Big Tech Co",
            "location": "Remote in New York",
            "date": "1 day ago",
            "link": "https://www.indeed.com/viewjob?jk=ghi789"
        },
        {
            "title": "Data Scientist - NLP",
            "company": "FinTech Solutions",
            "location": "New York or Remote",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=jkl101"
        },
        {
            "title": "Junior Data Scientist",
            "company": "StartUp Adventures",
            "location": "New York, NY",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=mno112"
        }
    ],
    "Software Engineer": [
        {
            "title": "Senior Software Engineer",
            "company": "CodeCraft Technologies",
            "location": "Remote",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=pqr131"
        },
        {
            "title": "Full Stack Software Engineer",
            "company": "WebDev Pros",
            "location": "Remote (US)",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=stu415"
        },
        {
            "title": "Backend Software Engineer - Python",
            "company": "Software Solutions Inc",
            "location": "Remote",
            "date": "1 day ago",
            "link": "https://www.indeed.com/viewjob?jk=vwx161"
        },
        {
            "title": "Frontend React Engineer",
            "company": "User Interface Co",
            "location": "Remote, US-based",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=yz1718"
        }
    ]
}

def search_indeed_jobs(job_title, location="remote", days=1, demo_mode=True):
    """
    Search Indeed for job listings based on job title and location
    Returns a list of job postings
    
    If demo_mode is True, returns sample data instead of making a real web request
    """
    # Use demo mode to avoid web scraping issues
    if demo_mode:
        logger.info(f"Using demo mode for job search: {job_title} in {location}")
        # Find the best match in our sample data
        if job_title in SAMPLE_JOBS:
            return SAMPLE_JOBS[job_title]
        # Try a partial match
        for title, jobs in SAMPLE_JOBS.items():
            if job_title.lower() in title.lower() or title.lower() in job_title.lower():
                return jobs
        # Return the first sample dataset as fallback
        return list(SAMPLE_JOBS.values())[0]
    
    # Below is the actual web scraping code, which might be blocked by Indeed
    try:
        # Format the search query
        query = urllib.parse.quote_plus(job_title)
        loc = urllib.parse.quote_plus(location)
        
        # Create URL for Indeed search
        url = f"https://www.indeed.com/jobs?q={query}&l={loc}&sort=date&fromage={days}"
        
        logger.info(f"Searching jobs with URL: {url}")
        
        # Set headers to avoid blocking
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
        
        # Send request to Indeed
        response = requests.get(url, headers=headers)
        
        if response.status_code != 200:
            logger.error(f"Failed to get Indeed response: {response.status_code}")
            return []
        
        # Parse the HTML content
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Extract job listings
        job_cards = soup.find_all('div', class_='job_seen_beacon')
        
        jobs = []
        for card in job_cards[:5]:  # Limit to 5 jobs
            try:
                # Extract job details
                title_elem = card.find('a', class_='jcs-JobTitle')
                company_elem = card.find('span', class_='companyName')
                location_elem = card.find('div', class_='companyLocation')
                date_elem = card.find('span', class_='date')
                link_elem = title_elem.get('href') if title_elem else None
                
                # Create job object
                job = {
                    'title': title_elem.text.strip() if title_elem else 'Unknown',
                    'company': company_elem.text.strip() if company_elem else 'Unknown',
                    'location': location_elem.text.strip() if location_elem else 'Unknown',
                    'date': date_elem.text.strip() if date_elem else 'Unknown',
                    'link': f"https://www.indeed.com{link_elem}" if link_elem else '#'
                }
                
                jobs.append(job)
            except Exception as e:
                logger.error(f"Error parsing job card: {str(e)}")
        
        return jobs
    
    except Exception as e:
        logger.error(f"Error searching Indeed jobs: {str(e)}")
        return []

def format_jobs_email(jobs, job_title):
    """Format job listings into an HTML email"""
    if not jobs:
        return f"No new {job_title} jobs found in the last 24 hours."
    
    html = f"""
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            h1 {{ color: #2557a7; }}
            .job {{ border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; border-radius: 5px; }}
            .job:hover {{ background-color: #f9f9f9; }}
            .job-title {{ color: #2557a7; font-size: 18px; margin-bottom: 5px; }}
            .company {{ font-weight: bold; }}
            .location {{ color: #666; }}
            .date {{ color: #666; font-style: italic; }}
            .apply {{ display: inline-block; background-color: #2557a7; color: white; padding: 8px 15px; 
                     text-decoration: none; border-radius: 4px; margin-top: 10px; }}
            .apply:hover {{ background-color: #1c4380; }}
        </style>
    </head>
    <body>
        <h1>Latest {job_title} Job Opportunities</h1>
        <p>Here are the latest job postings for {job_title} from the past 24 hours:</p>
    """
    
    for job in jobs:
        html += f"""
        <div class="job">
            <div class="job-title">{job['title']}</div>
            <div class="company">{job['company']}</div>
            <div class="location">{job['location']}</div>
            <div class="date">Posted: {job['date']}</div>
            <a href="{job['link']}" class="apply" target="_blank">View Job</a>
        </div>
        """
    
    html += """
    </body>
    </html>
    """
    
    return html

def format_jobs_sms(jobs, job_title):
    """Format job listings into a SMS message"""
    if not jobs:
        return f"No new {job_title} jobs found in the last 24 hours."
    
    sms = f"Latest {job_title} Jobs:\n\n"
    
    for i, job in enumerate(jobs[:3], 1):  # Limit to 3 jobs for SMS
        sms += f"{i}. {job['company']}: {job['title']}\n"
    
    sms += "\nReply STOP to unsubscribe."
    
    return sms

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_job_search.py \"Job Title\" [Location]")
        print("Example: python test_job_search.py \"Software Engineer\" \"Remote\"")
        sys.exit(1)
    
    job_title = sys.argv[1]
    location = sys.argv[2] if len(sys.argv) > 2 else "Remote"
    
    print(f"Searching for '{job_title}' jobs in '{location}'...")
    jobs = search_indeed_jobs(job_title, location, demo_mode=True)
    
    if not jobs:
        print("No jobs found.")
        sys.exit(0)
    
    print(f"\nFound {len(jobs)} jobs:\n")
    
    for i, job in enumerate(jobs, 1):
        print(f"{i}. {job['title']}")
        print(f"   Company: {job['company']}")
        print(f"   Location: {job['location']}")
        print(f"   Posted: {job['date']}")
        print(f"   Link: {job['link']}")
        print()
    
    # Format and print sample email
    email_content = format_jobs_email(jobs, job_title)
    with open("sample_email.html", "w") as f:
        f.write(email_content)
    print(f"Sample email saved to sample_email.html")
    
    # Format and print sample SMS
    sms_content = format_jobs_sms(jobs, job_title)
    print("\nSample SMS notification:")
    print("-" * 40)
    print(sms_content)
    print("-" * 40)
    
    # Save jobs to JSON file
    with open("jobs.json", "w") as f:
        json.dump(jobs, f, indent=2)
    print("Jobs saved to jobs.json")

if __name__ == "__main__":
    main() 