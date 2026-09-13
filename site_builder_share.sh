#!/bin/bash

set -e

################################################################################
# CONFIGURATION
################################################################################

PROJECT_DIR="/Users/[YOUR_USERNAME]/better_Live/LiveShowSite"
PROJECT_NAME="LiveShowSite"
APP_NAME="entertainment"
PYTHON_BIN="python3"
VENV_DIR="$PROJECT_DIR/venv"

EXTERNAL_BASE="/Users/[YOUR_USERNAME]/better_Live"
MEDIA_DIR="$EXTERNAL_BASE/media"
STATIC_DIR="$EXTERNAL_BASE/static"
VIDEO_THUMBS_DIR="$MEDIA_DIR/video_thumbnails"

STATIC_PAGES_DIR="$PROJECT_DIR/$APP_NAME/templates/static_pages"

# Matches what's actually live — the config-file/rotation approach was
# never adopted, so this stays hardcoded rather than half-migrated.
PRIVATE_FOLDER_NAME="[YOUR_Unique_Private_folder-NAME]"

################################################################################
# BACKUP DB, MEDIA, STATIC AND STATIC PAGES — THEN DELETE OLD PROJECT
################################################################################

echo "==> Cleaning old project..."

if [ -d "$PROJECT_DIR" ]; then
    BACKUP_DIR="/Users/[YOUR_USERNAME]/better_Live/backups"
    mkdir -p "$BACKUP_DIR/media_backup"

    if [ -f "$PROJECT_DIR/db.sqlite3" ]; then
        echo "==> Backing up existing db.sqlite3"
        cp "$PROJECT_DIR/db.sqlite3" "$BACKUP_DIR/db_backup.sqlite3"
    fi

    if [ -d "$PROJECT_DIR/media" ]; then
        echo "==> Backing up existing project media folder"
        cp -a "$PROJECT_DIR/media/." "$BACKUP_DIR/media_backup/"
    fi

    if [ -d "$MEDIA_DIR" ]; then
        echo "==> Backing up existing external media folder"
        mkdir -p "$BACKUP_DIR/media_backup_external"
        cp -a "$MEDIA_DIR/." "$BACKUP_DIR/media_backup_external/"
    fi

    if [ -d "$STATIC_DIR" ]; then
        echo "==> Backing up existing external static folder"
        mkdir -p "$BACKUP_DIR/static_backup_external"
        cp -a "$STATIC_DIR/." "$BACKUP_DIR/static_backup_external/"
    fi

    if [ -d "$STATIC_PAGES_DIR" ]; then
        echo "==> Backing up static_pages templates (incl. private folder)"
        mkdir -p "$BACKUP_DIR/static_pages_backup"
        cp -a "$STATIC_PAGES_DIR/." "$BACKUP_DIR/static_pages_backup/"
    fi

    rm -rf "$PROJECT_DIR"
fi

################################################################################
# CREATE VENV AND INSTALL DEPENDENCIES
################################################################################

echo "==> Creating virtual environment..."
$PYTHON_BIN -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "==> Installing Django + packages..."
pip install django django-allauth django-ckeditor moviepy pillow
# ffmpeg must be installed on the system, e.g.:  brew install ffmpeg

################################################################################
# START DJANGO PROJECT AND APP
################################################################################

echo "==> Creating Django project and app..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

django-admin startproject "$PROJECT_NAME" .
django-admin startapp "$APP_NAME"

mkdir -p "$MEDIA_DIR"
mkdir -p "$VIDEO_THUMBS_DIR"
mkdir -p "$STATIC_DIR"
mkdir -p "$STATIC_PAGES_DIR/$PRIVATE_FOLDER_NAME"

################################################################################
# DJANGO SETTINGS.PY
################################################################################

SETTINGS_FILE="$PROJECT_DIR/$PROJECT_NAME/settings.py"
cat > "$SETTINGS_FILE" << 'SETTINGS_PY'
from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent.parent
EXTERNAL_BASE = Path("/Users/[YOUR_USERNAME]/better_Live")

SECRET_KEY_FILE = EXTERNAL_BASE / "secret_key.txt"
if SECRET_KEY_FILE.exists():
    SECRET_KEY = SECRET_KEY_FILE.read_text().strip()
else:
    from django.core.management.utils import get_random_secret_key
    EXTERNAL_BASE.mkdir(parents=True, exist_ok=True)
    SECRET_KEY = get_random_secret_key()
    SECRET_KEY_FILE.write_text(SECRET_KEY)
    os.chmod(SECRET_KEY_FILE, 0o600)

DEBUG = os.environ.get("DJANGO_DEBUG", "False") == "True"
ALLOWED_HOSTS = os.environ.get(
    "DJANGO_ALLOWED_HOSTS", "127.0.0.1,localhost"
).split(",")

CSRF_TRUSTED_ORIGINS = [
    'http://[_YOUR_Onion_Address_].onion',
    'http://127.0.0.1:8000',
]

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.sites',
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'ckeditor',
    'ckeditor_uploader',
    'entertainment',
]

SITE_ID = 1
LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'
ACCOUNT_AUTHENTICATED_LOGIN_REDIRECTS = False

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'allauth.account.middleware.AccountMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'LiveShowSite.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / "templates"],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'LiveShowSite.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / "db.sqlite3",
    }
}

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [ EXTERNAL_BASE / 'static' ]

MEDIA_URL = '/media/'
MEDIA_ROOT = EXTERNAL_BASE / 'media'

CKEDITOR_UPLOAD_PATH = "uploads/"
CKEDITOR_ALLOW_NONIMAGE_FILES = False
CKEDITOR_UPLOAD_PERMISSION = "entertainment.custom_ckeditor_upload_permission"
X_FRAME_OPTIONS = 'SAMEORIGIN'
SETTINGS_PY

################################################################################
# MODELS
################################################################################

MODELS_FILE="$PROJECT_DIR/$APP_NAME/models.py"
cat > "$MODELS_FILE" << 'MODELS_PY'
from django.db import models
from django.contrib.auth.models import User
from ckeditor.fields import RichTextField

class Article(models.Model):
    title = models.CharField(max_length=200)
    content = RichTextField()
    author = models.ForeignKey(User, on_delete=models.CASCADE)
    created = models.DateTimeField(auto_now_add=True)
    image = models.ImageField(upload_to='article_images/', blank=True, null=True)

    def __str__(self):
        return self.title

class Photo(models.Model):
    caption = models.CharField(max_length=200)
    image = models.ImageField(upload_to='photos/')
    uploader = models.ForeignKey(User, on_delete=models.CASCADE)
    uploaded = models.DateTimeField(auto_now_add=True)

class Video(models.Model):
    title = models.CharField(max_length=200)
    video = models.FileField(upload_to='videos/')
    uploader = models.ForeignKey(User, on_delete=models.CASCADE)
    uploaded = models.DateTimeField(auto_now_add=True)
    thumbnail = models.ImageField(upload_to='video_thumbnails/', blank=True, null=True)
    custom_thumbnail = models.ImageField(upload_to='video_custom_thumbnails/', blank=True, null=True)

    def __str__(self):
        return self.title
MODELS_PY

################################################################################
# FORMS
################################################################################

FORMS_FILE="$PROJECT_DIR/$APP_NAME/forms.py"
cat > "$FORMS_FILE" << 'FORMS_PY'
from django import forms
from .models import Article, Photo, Video
from ckeditor.widgets import CKEditorWidget

class ArticleForm(forms.ModelForm):
    content = forms.CharField(widget=CKEditorWidget())
    class Meta:
        model = Article
        fields = ['title', 'content', 'image']

class PhotoForm(forms.ModelForm):
    class Meta:
        model = Photo
        fields = ['caption', 'image']

class VideoForm(forms.ModelForm):
    class Meta:
        model = Video
        fields = ['title', 'video', 'custom_thumbnail']
FORMS_PY

################################################################################
# APPS
################################################################################

APPS_FILE="$PROJECT_DIR/$APP_NAME/apps.py"
cat > "$APPS_FILE" << 'APPS_PY'
from django.apps import AppConfig


class EntertainmentConfig(AppConfig):
    name = 'entertainment'
    def ready(self):
        import entertainment.signals  # noqa
APPS_PY

################################################################################
# SIGNALS
################################################################################

SIGNALS_FILE="$PROJECT_DIR/$APP_NAME/signals.py"
cat > "$SIGNALS_FILE" << 'SIGNALS_PY'
from django.db import connection
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.urls import reverse
from .models import Article

def article_url(instance):
    return reverse("article_detail", args=[instance.pk])  # swap in the real name

@receiver(post_save, sender=Article)
def index_article(sender, instance, **kwargs):
    url = article_url(instance)
    with connection.cursor() as c:
        c.execute("DELETE FROM search_index WHERE url = %s", [url])
        c.execute(
            "INSERT INTO search_index (title, body, url, source_type) VALUES (%s, %s, %s, 'article')",
            [instance.title, instance.content, url],
        )

@receiver(post_delete, sender=Article)
def unindex_article(sender, instance, **kwargs):
    with connection.cursor() as c:
        c.execute("DELETE FROM search_index WHERE url = %s", [article_url(instance)])
SIGNALS_PY

################################################################################
# MANAGEMENT COMMANDS — index_static_pages, index_articles
# (rebuild_article_index.py intentionally dropped — duplicate of index_articles.py)
################################################################################

mkdir -p "$PROJECT_DIR/$APP_NAME/management/commands"
touch "$PROJECT_DIR/$APP_NAME/management/__init__.py"
touch "$PROJECT_DIR/$APP_NAME/management/commands/__init__.py"

INDEX_PAGES_FILE="$PROJECT_DIR/$APP_NAME/management/commands/index_static_pages.py"
cat > "$INDEX_PAGES_FILE" << 'INDEX_PAGES_PY'
import re
from html.parser import HTMLParser
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import connection

SKIP_FOLDERS = {"[YOUR_Unique_Private_folder-NAME]"}
SKIP_FILES = {
    ".DS_Store", "Thumbs.db", ".gitkeep",
    "file_index_earthlight.html", "file_index_private.html",
}


def strip_django_tags(text):
    text = re.sub(r"\{%.*?%\}", "", text, flags=re.DOTALL)
    text = re.sub(r"\{\{.*?\}\}", "", text, flags=re.DOTALL)
    text = re.sub(r"\{#.*?#\}", "", text, flags=re.DOTALL)
    return text


class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
    def handle_data(self, data):
        self.text.append(data)


class Command(BaseCommand):
    help = "Rebuilds search index entries for entertainment/templates/static_pages/*.html"

    def handle(self, *args, **kwargs):
        root = settings.BASE_DIR / "entertainment" / "templates" / "static_pages"
        count = 0
        with connection.cursor() as c:
            c.execute("DELETE FROM search_index WHERE source_type = 'page'")
            for html_file in root.rglob("*.html"):
                rel = html_file.relative_to(root)

                if any(part in SKIP_FOLDERS for part in rel.parts[:-1]):
                    continue
                if html_file.name in SKIP_FILES:
                    continue

                rel_noext = rel.with_suffix("")
                url = "http:/" + "/".join(rel_noext.parts) + "/"

                raw = html_file.read_text(encoding="utf-8", errors="ignore")
                raw = strip_django_tags(raw)
                parser = TextExtractor()
                parser.feed(raw)
                body = " ".join(parser.text)

                title = html_file.stem.replace("_", " ").replace("-", " ").title()
                c.execute(
                    "INSERT INTO search_index (title, body, url, source_type) VALUES (%s, %s, %s, 'page')",
                    [title, body, url],
                )
                count += 1
        self.stdout.write(f"Indexed {count} static pages.")
INDEX_PAGES_PY

INDEX_ARTICLES_FILE="$PROJECT_DIR/$APP_NAME/management/commands/index_articles.py"
cat > "$INDEX_ARTICLES_FILE" << 'INDEX_ARTICLES_PY'
from django.core.management.base import BaseCommand
from django.db import connection
from django.urls import reverse
from entertainment.models import Article

class Command(BaseCommand):
    help = "Rebuilds search index entries for every existing Article"

    def handle(self, *args, **kwargs):
        count = 0
        with connection.cursor() as c:
            c.execute("DELETE FROM search_index WHERE source_type = 'article'")
            for article in Article.objects.all():
                url = reverse("article_detail", args=[article.pk])
                c.execute(
                    "INSERT INTO search_index (title, body, url, source_type) VALUES (%s, %s, %s, 'article')",
                    [article.title, article.content, url],
                )
                count += 1
        self.stdout.write(f"Indexed {count} articles.")
INDEX_ARTICLES_PY

################################################################################
# VIEWS
################################################################################

VIEWS_FILE="$PROJECT_DIR/$APP_NAME/views.py"
cat > "$VIEWS_FILE" << 'VIEWS_PY'
import os
import subprocess
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib import messages
from django.http import HttpResponseForbidden, Http404
from django.template import TemplateDoesNotExist
from django.core.paginator import Paginator
from django.conf import settings
from allauth.account.views import SignupView

from .models import Article, Photo, Video
from .forms import ArticleForm, PhotoForm, VideoForm
from django.db import connection
from django.shortcuts import render

# --- Public Views ---

# Items per page for each tab.
ARTICLES_PER_PAGE = 8
VIDEOS_PER_PAGE = 6
PHOTOS_PER_PAGE = 8


def home(request):
    """Tabbed home page: Articles / Videos / Photos, each with its own
    independent paginator.

    Query parameters (all optional, all independent):
        page  — articles page number (same name as before, so old links work)
        vpage — videos page number
        ppage — photos page number
        tab   — which tab is active after a reload (articles|videos|photos)

    Every pagination link in home.html carries all three page numbers plus
    the tab name, so paging one tab never resets the other two.
    """
    articles = Article.objects.order_by('-created')
    photos = Photo.objects.order_by('-uploaded')
    videos = Video.objects.order_by('-uploaded')

    articles_page = Paginator(articles, ARTICLES_PER_PAGE).get_page(
        request.GET.get('page'))
    videos_page = Paginator(videos, VIDEOS_PER_PAGE).get_page(
        request.GET.get('vpage'))
    photos_page = Paginator(photos, PHOTOS_PER_PAGE).get_page(
        request.GET.get('ppage'))

    active_tab = request.GET.get('tab', 'articles')
    if active_tab not in ('articles', 'videos', 'photos'):
        active_tab = 'articles'

    return render(request, 'home.html', {
        'articles': articles_page,
        'videos': videos_page,
        'photos': photos_page,
        'active_tab': active_tab,
    })


def article_detail(request, pk):
    article = get_object_or_404(Article, pk=pk)
    return render(request, 'article_detail.html', {'article': article})


def article_snippet(request, pk):
    article = get_object_or_404(Article, pk=pk)
    return render(request, 'snippet.html', {'article': article})


def static_page(request, page):
    # Ensure any trailing slash is stripped from the path variable
    clean_page = page.strip('/')
    try:
        return render(request, f"static_pages/{clean_page}.html")
    except TemplateDoesNotExist:
        raise Http404("Page not found")


# --- Authentication & Registration Views ---

class RestrictedSignupView(LoginRequiredMixin, SignupView):
    """
    Gates signup so a new account can only be created by an authenticated user.
    Anonymous visitors hitting this route are automatically redirected to the login page
    by LoginRequiredMixin.

    CRITICAL: Requires ACCOUNT_AUTHENTICATED_REGISTRATION_REDIRECTS = False in settings.py
    so django-allauth doesn't automatically loop authenticated users back to the homepage.
    """
    template_name = 'account/signup.html'


# --- Article Management (Login Required) ---

@login_required
def create_article(request):
    if request.method == 'POST':
        form = ArticleForm(request.POST, request.FILES)
        if form.is_valid():
            a = form.save(commit=False)
            a.author = request.user
            a.save()
            return redirect('home')
    else:
        form = ArticleForm()
    return render(request, 'create_article.html', {'form': form})


@login_required
def edit_article(request, pk):
    article = get_object_or_404(Article, pk=pk)
    if article.author != request.user:
        return HttpResponseForbidden()
    if request.method == 'POST':
        form = ArticleForm(request.POST, request.FILES, instance=article)
        if form.is_valid():
            form.save()
            return redirect('home')
    else:
        form = ArticleForm(instance=article)
    return render(request, 'edit_article.html', {'form': form, 'article': article})


@login_required
def delete_article(request, pk):
    article = get_object_or_404(Article, pk=pk)
    if article.author != request.user:
        return HttpResponseForbidden()
    article.delete()
    return redirect('home')


# --- Photo Management (Login Required) ---

@login_required
def upload_photo(request):
    if request.method == 'POST':
        form = PhotoForm(request.POST, request.FILES)
        if form.is_valid():
            p = form.save(commit=False)
            p.uploader = request.user
            p.save()
            return redirect('home')
    else:
        form = PhotoForm()
    return render(request, 'upload_photo.html', {'form': form})


@login_required
def delete_photo(request, pk):
    photo = get_object_or_404(Photo, pk=pk)
    if photo.uploader != request.user:
        return HttpResponseForbidden()
    photo.delete()
    return redirect('home')


# --- Video Management (Login Required) ---

@login_required
def upload_video(request):
    if request.method == 'POST':
        form = VideoForm(request.POST, request.FILES)
        if form.is_valid():
            v = form.save(commit=False)
            v.uploader = request.user
            v.save()

            # Use custom thumbnail if provided
            if v.custom_thumbnail:
                v.thumbnail = v.custom_thumbnail
                v.save()
            else:
                # Auto-generate thumbnail
                input_file = v.video.path
                output_file = os.path.join(settings.MEDIA_ROOT, "video_thumbnails", f"thumb_{v.pk}.jpg")

                os.makedirs(os.path.dirname(output_file), exist_ok=True)

                try:
                    subprocess.run([
                        "ffmpeg",
                        "-i", input_file,
                        "-ss", "00:00:01",
                        "-vframes", "1",
                        "-vf", "scale=320:-1",
                        output_file
                    ], check=True)

                    rel_path = f"video_thumbnails/thumb_{v.pk}.jpg"
                    v.thumbnail = rel_path
                    v.save()

                except Exception as e:
                    print("Thumbnail generation failed:", e)

            return redirect('home')
    else:
        form = VideoForm()
    return render(request, 'upload_video.html', {'form': form})


@login_required
def delete_video(request, pk):
    video = get_object_or_404(Video, pk=pk)
    if video.uploader != request.user:
        return HttpResponseForbidden()
    video.delete()
    return redirect('home')


# --- Third-Party Integrations ---

def custom_ckeditor_upload_permission(user):
    return user.is_authenticated

def search(request):
    q = request.GET.get("q", "").strip()
    results = []
    if q:
        with connection.cursor() as c:
            c.execute(
                """
                SELECT title, url, source_type,
                       snippet(search_index, 1, '<mark>', '</mark>', '…', 10) AS excerpt
                FROM search_index
                WHERE search_index MATCH %s
                ORDER BY bm25(search_index)
                LIMIT 30
                """,
                [q],
            )
            results = c.fetchall()
    return render(request, "search.html", {"query": q, "results": results})
VIEWS_PY

################################################################################
# URLS
################################################################################

URLS_FILE="$PROJECT_DIR/$PROJECT_NAME/urls.py"
cat > "$URLS_FILE" << 'URLS_PY'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.views.static import serve
from entertainment import views
from entertainment.views import search

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/signup/', views.RestrictedSignupView.as_view(), name='account_signup'),
    path('accounts/', include('allauth.urls')),
    path('', views.home, name='home'),
    path('article/create/', views.create_article, name='create_article'),
    path('article/<int:pk>/', views.article_detail, name='article_detail'),
    path('article/<int:pk>/edit/', views.edit_article, name='edit_article'),
    path('article/<int:pk>/delete/', views.delete_article, name='delete_article'),
    path('article-snippet/<int:pk>/', views.article_snippet, name='article_snippet'),

    path('photo/upload/', views.upload_photo, name='upload_photo'),
    path('photo/<int:pk>/delete/', views.delete_photo, name='delete_photo'),

    path('video/upload/', views.upload_video, name='upload_video'),
    path('video/<int:pk>/delete/', views.delete_video, name='video_delete'),

    path('ckeditor/', include('ckeditor_uploader.urls')),
    path("search/", search, name="search"),
]

urlpatterns += [
    path('media/<path:path>', serve, {'document_root': settings.MEDIA_ROOT}),
    # CHANGED THIS LINE BELOW TO USE STATIC_ROOT FOR CKEDITOR ASSETS:
    path('static/<path:path>', serve, {'document_root': settings.STATIC_ROOT}),

   # CHANGE '<str:page>/' TO '<path:page>/'
    path('<path:page>/', views.static_page, name='static_page'),
]
URLS_PY

################################################################################
# TEMPLATES
################################################################################

mkdir -p "$PROJECT_DIR/templates"
mkdir -p "$PROJECT_DIR/templates/account"

cat > "$PROJECT_DIR/templates/base.html" << 'BASE_HTML'
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>EarthLight Magazine</title>

  <!-- Bootstrap CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

  <!-- Favicon -->
  <link rel="icon" href="{% static 'images/favicon.ico' %}" type="image/x-icon">
  <link rel="shortcut icon" href="{% static 'images/favicon.ico' %}" type="image/x-icon">

  <!-- Custom CSS -->
  <style>
  body::before {
  content: "";
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-image: url("{% static 'images/earth.jpg' %}");
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
  opacity: 0.18;          /* adjust translucency here */
  z-index: -1;            /* behind all content */
}

/* Translucent navbar styles */
.translucent-dark {
  background-color: rgba(33, 37, 41, 0.55) !important;
}

.translucent-red {
  background-color: rgba(255, 0, 0, 0.60) !important;
}
   /* Make navbar links more visible */
.navbar-nav .nav-link {
  font-weight: 600;
  font-size: 1.1rem;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5);
}

/* Make the red navbar links more visible */
.navbar[style*="background-color: red"] .nav-link {
  color: white !important;
  font-weight: 600;
  font-size: 1.05rem;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.7);
}

/* Hover effects */
.navbar-nav .nav-link:hover {
  color: #fff !important;
  transform: scale(1.05);
  transition: all 0.2s ease;
}

.navbar[style*="background-color: red"] .nav-link:hover {
  color: #ffff99 !important;
  text-decoration: underline;
}

    /* Images inside cards, articles, and content scale properly */
    .card-img-top,
    .article-content img,
    .recent-photos img,
    .main-content img {
      width: 100%;
      height: auto !important;
      object-fit: contain !important;
    }

    /* Logo styling */
    .navbar-brand img.site-logo {
      max-height: 50px;
      width: auto;
      margin-right: 8px;
      object-fit: contain;
    }

    /* Card image tweak for cover effect */
    .card-img-top { object-fit: cover; }

    /* Video card background */
    .video-card .ratio { background: #000; }

    /* Footer styling */
    footer {
      font-size: 0.9rem;
      color: #6c757d;
      padding: 1rem 0;
    }

    /* Article snippet hover effects */
    .article-snippet {
      cursor: pointer;
      color: #333;
      text-decoration: none;
      display: block;
      padding: 8px 0;
    }
    .article-snippet:hover {
      color: #0d6efd;
      background-color: #f8f9fa;
    }
  </style>
</head>
<body>
  <!-- Navbar -->
<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-0 translucent-dark">
    <div class="container">
      <a class="navbar-brand d-flex align-items-center" href="{% url 'home' %}">
        <img src="{% static 'images/logo.png' %}" class="site-logo" alt="Logo">
        EarthLight  Foundation Magazine
      </a>
      <div class="collapse navbar-collapse" id="navcoll">
        <ul class="navbar-nav ms-auto">
          {% if user.is_authenticated %}
            <li class="nav-item"><a class="nav-link" href="{% url 'create_article' %}">Submit Article</a></li>
            <li class="nav-item"><a class="nav-link" href="{% url 'upload_photo' %}">Upload Photo</a></li>
            <li class="nav-item"><a class="nav-link" href="{% url 'upload_video' %}">Upload Video</a></li>
            <li class="nav-item"><a class="nav-link" href="{% url 'account_signup' %}">Add New Member</a></li>
            <li class="nav-item"><a class="nav-link" href="{% url 'account_logout' %}">Logout ({{ user.username }})</a></li>
          {% else %}
            <li class="nav-item"><a class="nav-link" href="{% url 'account_login' %}">Login</a></li>
          {% endif %}
        </ul>
      </div>
    </div>
  </nav>
<nav class="navbar py-1 translucent-red">
  <div class="container-fluid" style="text-align: center;">
    <a class="nav-link px-2" href="/about/" style="color: white;">About</a>
    <a class="nav-link px-2" href="/article/2/" style="color: white;">Featured Article</a>
    <a class="nav-link px-2" href="/file_index_earthlight" style="color: white;">Site Map</a>
    <a class="nav-link px-2" href="/fav_pics" style="color: white;">Favorite Pics</a>
    <a class="nav-link px-2" href="/contact/" style="color: white;">Contact Us!</a>
    {% include "search_widget.html" %}
    <!-- Add more custom static links here -->
  </div>
</nav>

  <!-- Main content -->
  <main class="container">
    {% if messages %}
      {% for message in messages %}
        <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
          {{ message }}
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      {% endfor %}
    {% endif %}

    {% block content %}{% endblock %}
  </main>

  <!-- Footer -->
  <footer class="text-center mt-4">
    &copy; {{ now|date:"Y" }} EarthLight Magazine and Member Web Blog
  </footer>

  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  {% block extra_scripts %}{% endblock %}
</body>
</html>
BASE_HTML

cat > "$PROJECT_DIR/templates/search_widget.html" << 'SEARCH_WIDGET_HTML'
<form method="get" action="{% url 'search' %}" class="search-widget">
    <input type="text" name="q" value="{{ query|default:'' }}" placeholder="Search articles and pages">
    <button type="submit">Search</button>
</form>
SEARCH_WIDGET_HTML

cat > "$PROJECT_DIR/templates/home.html" << 'HOME_HTML'
{% extends "base.html" %}
{% block content %}
<h2 class="text-center mb-4">Post Articles, Videos, and Images.</h2>
<style>
  .home-tabs .nav-link { font-weight: 600; color: #333; background: rgba(255,255,255,.55); }
  .home-tabs .nav-link.active { background: rgba(255,255,255,.92); color: #dc3545; }
  .tab-content { background: rgba(255,255,255,.35); border: 1px solid #dee2e6; border-top: 0; border-radius: 0 0 .5rem .5rem; padding: 1.25rem; }
</style>
<ul class="nav nav-tabs home-tabs" id="homeTabs" role="tablist">
  <li class="nav-item" role="presentation">
    <button class="nav-link {% if active_tab == 'articles' %}active{% endif %}" data-bs-toggle="tab" data-bs-target="#tab-articles" type="button" role="tab">Articles
      <span class="badge bg-secondary bg-opacity-50">{{ articles.paginator.count }}</span></button>
  </li>
  <li class="nav-item" role="presentation">
    <button class="nav-link {% if active_tab == 'videos' %}active{% endif %}" data-bs-toggle="tab" data-bs-target="#tab-videos" type="button" role="tab">Videos
      <span class="badge bg-secondary bg-opacity-50">{{ videos.paginator.count }}</span></button>
  </li>
  <li class="nav-item" role="presentation">
    <button class="nav-link {% if active_tab == 'photos' %}active{% endif %}" data-bs-toggle="tab" data-bs-target="#tab-photos" type="button" role="tab">Photos
      <span class="badge bg-secondary bg-opacity-50">{{ photos.paginator.count }}</span></button>
  </li>
</ul>
<div class="tab-content" id="homeTabsContent">
  <div class="tab-pane fade {% if active_tab == 'articles' %}show active{% endif %}" id="tab-articles" role="tabpanel">
    <div class="row">
      {% for article in articles %}
        <div class="col-lg-3 col-md-4 col-sm-6 mb-3">
          <div class="card h-100">
            {% if article.image %}<img src="{{ article.image.url }}" class="card-img-top" alt="{{ article.title }}" style="height:140px;">{% endif %}
            <div class="card-body p-2">
              <h6 class="card-title mb-1">{{ article.title }}</h6>
              <p class="card-text small text-dark my-2">{{ article.content|striptags|truncatewords:20 | safe }}</p>
              <a href="{% url 'article_detail' article.pk %}" class="btn btn-sm btn-outline-primary mt-2 d-block">Read Article</a>
              {% if user == article.author %}
                <div class="mt-2 d-flex gap-1">
                  <a href="{% url 'edit_article' article.pk %}" class="btn btn-sm btn-warning w-50">Edit</a>
                  <a href="{% url 'delete_article' article.pk %}" class="btn btn-sm btn-danger w-50" onclick="return confirm('Delete this article?');">Delete</a>
                </div>
              {% endif %}
              <p class="text-muted mt-2 mb-0"><small>By {{ article.author.username }} on {{ article.created|date:"M d, Y" }}</small></p>
            </div>
          </div>
        </div>
      {% empty %}<p>No articles yet.</p>{% endfor %}
    </div>
    {% if articles.has_other_pages %}
      <nav><ul class="pagination justify-content-center">
        {% if articles.has_previous %}<li class="page-item"><a class="page-link" href="?tab=articles&page={{ articles.previous_page_number }}&vpage={{ videos.number }}&ppage={{ photos.number }}">Previous</a></li>{% endif %}
        <li class="page-item disabled"><span class="page-link">Page {{ articles.number }} of {{ articles.paginator.num_pages }}</span></li>
        {% if articles.has_next %}<li class="page-item"><a class="page-link" href="?tab=articles&page={{ articles.next_page_number }}&vpage={{ videos.number }}&ppage={{ photos.number }}">Next</a></li>{% endif %}
      </ul></nav>
    {% endif %}
  </div>
  <div class="tab-pane fade {% if active_tab == 'videos' %}show active{% endif %}" id="tab-videos" role="tabpanel">
    <div class="row">
      {% for video in videos %}
        <div class="col-lg-4 col-md-6 mb-4">
          <div class="card h-100 video-card">
            <div class="ratio ratio-16x9">
              <video controls preload="none" class="w-100" {% if video.thumbnail %} poster="{{ video.thumbnail.url }}" {% endif %}>
                <source src="{{ video.video.url }}" type="video/mp4">Your browser does not support the video tag.</video>
            </div>
            <div class="card-body p-2">
              <h6 class="card-title">{{ video.title }}</h6>
              <p class="text-muted"><small>By {{ video.uploader.username }} on {{ video.uploaded|date:"M d, Y" }}</small></p>
              {% if user == video.uploader %}<div class="mt-2"><a href="{% url 'video_delete' video.pk %}" class="btn btn-sm btn-danger" onclick="return confirm('Delete this video?');">Delete</a></div>{% endif %}
            </div>
          </div>
        </div>
      {% empty %}<p>No videos yet.</p>{% endfor %}
    </div>
    {% if videos.has_other_pages %}
      <nav><ul class="pagination justify-content-center">
        {% if videos.has_previous %}<li class="page-item"><a class="page-link" href="?tab=videos&vpage={{ videos.previous_page_number }}&page={{ articles.number }}&ppage={{ photos.number }}">Previous</a></li>{% endif %}
        <li class="page-item disabled"><span class="page-link">Page {{ videos.number }} of {{ videos.paginator.num_pages }}</span></li>
        {% if videos.has_next %}<li class="page-item"><a class="page-link" href="?tab=videos&vpage={{ videos.next_page_number }}&page={{ articles.number }}&ppage={{ photos.number }}">Next</a></li>{% endif %}
      </ul></nav>
    {% endif %}
  </div>
  <div class="tab-pane fade {% if active_tab == 'photos' %}show active{% endif %}" id="tab-photos" role="tabpanel">
    <div class="row">
      {% for photo in photos %}
        <div class="col-lg-3 col-md-4 col-6 mb-3">
          <div class="card h-100">
            <img src="{{ photo.image.url }}" class="card-img-top" alt="{{ photo.caption }}" style="height:140px;">
            <div class="card-body p-2">
              <p class="card-text">{{ photo.caption }}</p>
              <p class="text-muted"><small>By {{ photo.uploader.username }} on {{ photo.uploaded|date:"M d, Y" }}</small></p>
              {% if user == photo.uploader %}<div class="mt-2"><a href="{% url 'delete_photo' photo.pk %}" class="btn btn-sm btn-danger" onclick="return confirm('Delete this photo?');">Delete Photo</a></div>{% endif %}
            </div>
          </div>
        </div>
      {% empty %}<p>No photos yet.</p>{% endfor %}
    </div>
    {% if photos.has_other_pages %}
      <nav><ul class="pagination justify-content-center">
        {% if photos.has_previous %}<li class="page-item"><a class="page-link" href="?tab=photos&ppage={{ photos.previous_page_number }}&page={{ articles.number }}&vpage={{ videos.number }}">Previous</a></li>{% endif %}
        <li class="page-item disabled"><span class="page-link">Page {{ photos.number }} of {{ photos.paginator.num_pages }}</span></li>
        {% if photos.has_next %}<li class="page-item"><a class="page-link" href="?tab=photos&ppage={{ photos.next_page_number }}&page={{ articles.number }}&vpage={{ videos.number }}">Next</a></li>{% endif %}
      </ul></nav>
    {% endif %}
  </div>
</div>
{% endblock %}
HOME_HTML

cat > "$PROJECT_DIR/templates/article_detail.html" << 'DETAIL_HTML'
{% extends "base.html" %}
{% block content %}
<div class="container my-4">
  <div class="card p-4 bg-light shadow-sm">
    <h1 class="mb-2">{{ article.title }}</h1>
    <p class="text-muted mb-4"><small>By {{ article.author.username }} on {{ article.created|date:"M d, Y" }}</small></p>
    {% if article.image %}<div class="mb-4 text-center"><img src="{{ article.image.url }}" class="img-fluid rounded" alt="{{ article.title }}" style="max-height: 500px;"></div>{% endif %}
    <div class="article-content fs-5 line-height-base">{{ article.content|safe }}</div>
    <div class="mt-4 pt-3 border-top d-flex gap-2">
      <a href="{% url 'home' %}" class="btn btn-secondary">Back to Home</a>
      {% if user == article.author %}
        <a href="{% url 'edit_article' article.pk %}" class="btn btn-warning">Edit</a>
        <a href="{% url 'delete_article' article.pk %}" class="btn btn-danger" onclick="return confirm('Delete this article?');">Delete</a>
      {% endif %}
    </div>
  </div>
</div>
{% endblock %}
DETAIL_HTML

cat > "$PROJECT_DIR/templates/snippet.html" << 'SNIPPET_HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><style>body{font-family:Arial,Helvetica,sans-serif;padding:8px}</style></head>
  <body>
    <h6>{{ article.title }}</h6>
    <div>{{ article.content|striptags|truncatewords:30|safe }}</div>
  </body>
</html>
SNIPPET_HTML

cat > "$PROJECT_DIR/templates/create_article.html" << 'CREATE_HTML'
{% extends "base.html" %}
{% block content %}
<h2>Create Article</h2>
<form method="post" enctype="multipart/form-data">
    {% csrf_token %}
    {{ form.media }}
    {{ form.as_p }}
    <button type="submit">Post</button>
</form>
{% endblock %}
CREATE_HTML

cat > "$PROJECT_DIR/templates/edit_article.html" << 'EDIT_HTML'
{% extends "base.html" %}
{% block content %}
<h2>Edit Article: {{ article.title }}</h2>
<form method="post" enctype="multipart/form-data">
    {% csrf_token %}
    {{ form.media }}
    {{ form.as_p }}
    <button type="submit">Save</button>
</form>
{% endblock %}
EDIT_HTML

cat > "$PROJECT_DIR/templates/upload_photo.html" << 'PHOTO_HTML'
{% extends "base.html" %}
{% block content %}
<h2>Upload Photo</h2>
<form method="post" enctype="multipart/form-data">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">Upload</button>
</form>
{% endblock %}
PHOTO_HTML

cat > "$PROJECT_DIR/templates/upload_video.html" << 'VIDEO_HTML'
{% extends "base.html" %}
{% block content %}
<h2>Upload Video</h2>
<form method="post" enctype="multipart/form-data">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">Upload</button>
</form>
{% endblock %}
VIDEO_HTML

cat > "$PROJECT_DIR/templates/search.html" << 'SEARCH_HTML'
{% extends "base.html" %}
{% block content %}
<h1>Search</h1>
<form method="get" action="{% url 'search' %}">
    <input type="text" name="q" value="{{ query }}" placeholder="Search articles and pages">
    <button type="submit">Search</button>
</form>

{% if query %}
    <p>{{ results|length }} result{{ results|length|pluralize }} for "{{ query }}"</p>
{% endif %}

<ul>
    {% for title, url, source_type, excerpt in results %}
    <li>
        <a href="{{ url }}">{{ title }}</a> <small>({{ source_type }})</small>
        <p>{{ excerpt|safe }}</p>
    </li>
    {% endfor %}
</ul>
{% endblock %}
SEARCH_HTML

cat > "$PROJECT_DIR/templates/account/signup.html" << 'SIGNUP_HTML'
{% extends "base.html" %}
{% load i18n %}
{% load account socialaccount %}

{% block head_title %}{% trans "Sign Up" %}{% endblock %}

{% block content %}
<div class="container my-5" style="max-width: 500px;">
  <div class="card p-4 shadow-sm bg-light">
    <h2 class="mb-3 text-center">{% trans "Sign Up" %}</h2>

    <form class="signup" id="signup_form" method="POST" action="{% url 'account_signup' %}">
      {% csrf_token %}

      {{ form.as_p }}

      {% if redirect_field_value %}
        <input type="hidden" name="{{ redirect_field_name }}" value="{{ redirect_field_value }}" />
      {% endif %}

      <button class="btn btn-primary w-100 mt-3" type="submit">{% trans "Sign Up" %}</button>
    </form>

    <div class="text-center mt-3">
      <small class="text-muted">
        {% blocktrans %}Already have an account? <a href="{{ login_url }}">Sign In</a>.{% endblocktrans %}
      </small>
    </div>
  </div>
</div>
{% endblock %}
SIGNUP_HTML

cat > "$PROJECT_DIR/templates/account/login.html" << 'LOGIN_HTML'
{% extends "base.html" %}
{% load i18n %}
{% load account socialaccount %}

{% block head_title %}{% trans "Sign In" %}{% endblock %}

{% block content %}
<div class="container my-5" style="max-width: 500px;">
  <div class="card p-4 shadow-sm bg-light">
    <h2 class="mb-3 text-center">{% trans "Sign In" %}</h2>

    <form class="login" method="POST" action="{% url 'account_login' %}">
      {% csrf_token %}

      {{ form.as_p }}

      {% if redirect_field_value %}
        <input type="hidden" name="{{ redirect_field_name }}" value="{{ redirect_field_value }}" />
      {% endif %}

      <button class="btn btn-primary w-100 mt-3" type="submit">{% trans "Sign In" %}</button>
    </form>
  </div>
</div>
{% endblock %}
LOGIN_HTML

################################################################################
# MIGRATIONS
################################################################################

echo "==> Running makemigrations..."
python manage.py makemigrations

SEARCH_MIGRATION="$PROJECT_DIR/$APP_NAME/migrations/0002_search_index.py"
cat > "$SEARCH_MIGRATION" << 'MIGRATION_PY'
from django.db import migrations

SQL_CREATE = """
CREATE VIRTUAL TABLE search_index USING fts5(
    title, body, url, source_type,
    tokenize = 'porter unicode61'
);
"""
SQL_DROP = "DROP TABLE search_index;"

class Migration(migrations.Migration):

    dependencies = [
        ("entertainment", "0001_initial"),
    ]

    operations = [
        migrations.RunSQL(SQL_CREATE, reverse_sql=SQL_DROP),
    ]
MIGRATION_PY

echo "==> Running migrate..."
python manage.py migrate

echo "==> Collecting static files (needed since DEBUG is off by default)..."
python manage.py collectstatic --noinput

################################################################################
# RESTORE DB, MEDIA, STATIC, AND STATIC PAGES
################################################################################

BACKUP_DIR="/Users/[YOUR_USERNAME]/better_Live/backups"

if [ -f "$BACKUP_DIR/db_backup.sqlite3" ]; then
    echo "==> Restoring backup DB..."
    cp "$BACKUP_DIR/db_backup.sqlite3" "$PROJECT_DIR/db.sqlite3"
fi

if [ -d "$BACKUP_DIR/media_backup" ]; then
    echo "==> Restoring backup media folder into external MEDIA_DIR..."
    mkdir -p "$MEDIA_DIR"
    cp -r "$BACKUP_DIR/media_backup/." "$MEDIA_DIR"
    chmod -R 755 "$MEDIA_DIR"
fi

if [ -d "$BACKUP_DIR/media_backup_external" ]; then
    echo "==> Restoring external-media backup into external MEDIA_DIR (merge)..."
    mkdir -p "$MEDIA_DIR"
    cp -r "$BACKUP_DIR/media_backup_external/." "$MEDIA_DIR"
    chmod -R 755 "$MEDIA_DIR"
fi

if [ -d "$BACKUP_DIR/static_backup_external" ]; then
    echo "==> Restoring external static folder..."
    mkdir -p "$STATIC_DIR"
    cp -r "$BACKUP_DIR/static_backup_external/." "$STATIC_DIR"
    chmod -R 755 "$STATIC_DIR"
fi

if [ -d "$BACKUP_DIR/static_pages_backup" ]; then
    echo "==> Restoring static_pages templates..."
    mkdir -p "$STATIC_PAGES_DIR"
    cp -a "$BACKUP_DIR/static_pages_backup/." "$STATIC_PAGES_DIR/"
fi

python manage.py collectstatic --noinput

################################################################################
# REBUILD THE SEARCH INDEX AND SITE MAP
################################################################################

echo "==> Rebuilding search index..."
python manage.py index_static_pages
python manage.py index_articles

echo "==> Regenerating the site map..."
python3 "$EXTERNAL_BASE/index_public_pages.py"

echo "==> Setup complete. Run server with:"
echo "source $VENV_DIR/bin/activate && python manage.py runserver"
echo "Local dev with full error pages:  export DJANGO_DEBUG=True  first."
echo "Live over Tor: leave DJANGO_DEBUG unset; the onion origin is already"
echo "in CSRF_TRUSTED_ORIGINS."
echo ""
echo "Reminder: index_public_pages.py and private_pages_index.py both need"
echo "to live in $EXTERNAL_BASE — not inside LiveShowSite/ — or this script"
echo "will delete them on the next rebuild."

exit 0

