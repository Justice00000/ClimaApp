# ClimaTrack 
**AI-Powered Climate Risk and Health Insight System**  
**Author:** Justice Chukwuonye  
**GitHub Repository:** [ClimaTrack](https://github.com/Justice00000/Clima-Track/)  
**Demo Video (6 min):** [Video Demo](https://youtube.com/shorts/wiGlZLavFPs?feature=share)
**Download the App using this link** [ClimaTrack](https://drive.google.com/file/d/1N6wHcVsQT_bvVg_x7JpSTeUERbb72WK3/view?usp=drivesdk)

**Prototype:** 

![Home Page](https://i.imgur.com/Iuqz81S.png)
![Map Page](https://i.imgur.com/lwQNHZM.png)
![Report Page](https://i.imgur.com/iNoVyEN.png)
![Health Page](https://i.imgur.com/2vT4WMl.png)
![Learn Page](https://i.imgur.com/BYC9GXN.png)
 



## Description  
ClimaTrack is a prototype web application that predicts and visualizes the relationship between climate conditions and potential health risks.  
The system combines climate and environmental data with a machine-learning model trained in Python to generate intelligent insights for users and communities.  

This submission represents the **initial MVP** — including the prototype interface screenshots, ML notebook, and a short demo video showing functionality and user flow.


## Code Files

Include:

- `notebooks/ClimaTrack.ipynb`  
- `backend/` 
- `frontend/` —   
- `requirements.txt`  
- `README.md` 

## Deployment Plan

- **Backend:** Hosted on **Render** (Python FastAPI backend).  
- **Frontend:** Deployed via **Flutter Web Build** on **Firebase Hosting**.  
- **Database:** **Postgres**. 
- **Model:** Deployed as an **API endpoint** for integration with the frontend.  

# Prerequisites

Install the following software:

- **Python 3.8+** → [https://www.python.org/downloads/](https://www.python.org/downloads/)
- **Flutter SDK 3.0+** → [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- **Google Chrome** → [https://www.google.com/chrome/](https://www.google.com/chrome/)

---

# Backend Setup

### Step 1: Navigate to backend directory
```bash
cd backend
```
## Step 2: Create and activate virtual environment

### Windows:
```bash
python -m venv venv
venv\Scripts\activate
```

### macOS/Linux:
```bash
python3 -m venv venv
source venv/bin/activate
```
---

## Step 3: Install dependencies
```bash
pip install fastapi uvicorn pydantic bcrypt pyjwt geopy numpy python-multipart email-validator
```

---

## Step 4: Run the backend server
```bash
python main.py
```

**Backend should now be running at:** [http://localhost:8000](http://localhost:8000)

> Keep this terminal open and open a new terminal for the frontend.

---

# Frontend Setup

## Step 1: Navigate to project root
```bash
cd /path/to/climatrack
```

## Step 2: Install Flutter dependencies
```bash
flutter pub get
```

## Step 3: Run the app

### For Web:
```bash
flutter run -d chrome
```

### For Android:
```bash
flutter run
```

### For iOS (macOS only):
```bash
flutter run -d iPhone
```

### To build Android APK:
```bash
flutter build apk --release
```

**App should now be running!**

---

# Test the Application

1. Open the app (it should show the **login screen**)
2. Click **"Sign up"** to create a test account
3. Fill in the form with any test data
4. Click **"Create Account"**
5. Explore the app — *Dashboard, Map, Report, Health, Learn*

---

# Verify Backend is Working

Open your browser and go to:

- **API Docs:** [http://localhost:8000/api/docs](http://localhost:8000/api/docs)  
- **Health Check:** [http://localhost:8000/health](http://localhost:8000/health)

