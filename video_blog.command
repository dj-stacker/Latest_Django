#!/bin/bash
set -e

##############################################################################
# LiveShowSite: Full-featured Django membership blog site with:
# - Allauth authentication
# - Bootstrap styling
# - Media/image/video upload
# - Article/photo/video submission
# - Pagination, detail pages, editing
# - iFrame-based article snippets on homepage
# - CKEditor upload access for regular users (not just admins)
# - Member-uploaded thumbnails for videos
# - Auto-generated thumbnails using ffmpeg if none uploaded
##############################################################################

PROJECT_NAME="LiveShowSite"
APP_NAME="entertainment"
VENV_NAME="venv"

# 🔴 NOTE: Add your custom Python path here if necessary

# Clean and create project directory
rm -rf $PROJECT_NAME
mkdir $PROJECT_NAME
cd $PROJECT_NAME
python3 -m venv $VENV_NAME
source $VENV_NAME/bin/activate
pip install --upgrade pip
pip install django django-allauth pillow django-ckeditor

# Start Django project and app
django-admin startproject $PROJECT_NAME .
python manage.py startapp $APP_NAME

SETTINGS="$PROJECT_NAME/settings.py"

if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_FLAG="-i ''"
else
    SED_FLAG="-i"
fi

# Add installed apps
sed $SED_FLAG "s/'django.contrib.staticfiles',/&\
    'django.contrib.sites',\
    'allauth',\
    'allauth.account',\
    'allauth.socialaccount',\
    'ckeditor',\
    'ckeditor_uploader',\
    '$APP_NAME',/" $SETTINGS

# Add middleware
sed $SED_FLAG "s/'django.middleware.common.CommonMiddleware',/'allauth.account.middleware.AccountMiddleware',\
    'django.middleware.common.CommonMiddleware',/" $SETTINGS

# Add configuration
cat >> $SETTINGS <<EOF

AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
    'allauth.account.auth_backends.AuthenticationBackend',
]

SITE_ID = 1
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'static'
LOGIN_REDIRECT_URL = '/'
ACCOUNT_LOGOUT_REDIRECT_URL = '/'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

CKEDITOR_UPLOAD_PATH = "uploads/"
CKEDITOR_CONFIGS = {
    'default': {
        'toolbar': 'full',
        'height': 300,
        'width': '100%',
    },
}

CKEDITOR_UPLOAD_PERMISSION = 'entertainment.views.custom_ckeditor_upload_permission'
X_FRAME_OPTIONS = 'SAMEORIGIN'
EOF

# Project URLs
cat > $PROJECT_NAME/urls.py <<EOF
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from ckeditor_uploader import views as ck_views
from django.contrib.auth.decorators import login_required

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('allauth.urls')),
    path('ckeditor/upload/', login_required(ck_views.upload), name='ckeditor_upload'),
    path('ckeditor/browse/', login_required(ck_views.browse), name='ckeditor_browse'),
    path('ckeditor/', include('ckeditor_uploader.urls')),
    path('', include('$APP_NAME.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOF
# Admin, Forms, Templates, URLs etc. are unchanged from your current version
# Admin registration
cat > $APP_NAME/admin.py <<EOF
from django.contrib import admin
from .models import Article, Photo, Video

@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'created']
    list_filter = ['created', 'author']
    search_fields = ['title', 'content']

@admin.register(Photo)
class PhotoAdmin(admin.ModelAdmin):
    list_display = ['caption', 'uploader', 'uploaded']
    list_filter = ['uploaded', 'uploader']
    search_fields = ['caption']
    
@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    list_display = ['title', 'uploader', 'uploaded']
    list_filter = ['uploaded', 'uploader']
    search_fields = ['title']

EOF

# Forms
cat > $APP_NAME/forms.py <<EOF
from django import forms
from ckeditor_uploader.widgets import CKEditorUploadingWidget
from .models import Article, Photo

class ArticleForm(forms.ModelForm):
    class Meta:
        model = Article
        fields = ['title', 'content', 'image']
        widgets = {
            'title': forms.TextInput(attrs={'class': 'form-control'}),
            'content': CKEditorUploadingWidget(attrs={'class': 'form-control'}),
            'image': forms.ClearableFileInput(attrs={'class': 'form-control'}),
        }

class PhotoForm(forms.ModelForm):
    class Meta:
        model = Photo
        fields = ['image', 'caption']
        widgets = {
            'image': forms.FileInput(attrs={'class': 'form-control'}),
            'caption': forms.TextInput(attrs={'class': 'form-control'}),
        }

from .models import Video

from .models import Video

class VideoForm(forms.ModelForm):
    class Meta:
        model = Video
        fields = ['video', 'title', 'thumbnail']  # ✅ Added thumbnail
        widgets = {
            'video': forms.FileInput(attrs={'class': 'form-control'}),
            'title': forms.TextInput(attrs={'class': 'form-control'}),
            'thumbnail': forms.ClearableFileInput(attrs={'class': 'form-control'}),
        }


EOF


# MODELS.PY (overwrite with updated model)
cat > $APP_NAME/models.py <<EOF
from django.db import models
from django.contrib.auth.models import User
from ckeditor_uploader.fields import RichTextUploadingField

class Article(models.Model):
    title = models.CharField(max_length=200)
    content = RichTextUploadingField()
    image = models.ImageField(upload_to='articles/', blank=True, null=True)
    author = models.ForeignKey(User, on_delete=models.CASCADE)
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created']

    def __str__(self):
        return self.title

class Photo(models.Model):
    image = models.ImageField(upload_to='photos/')
    caption = models.CharField(max_length=200, blank=True)
    uploader = models.ForeignKey(User, on_delete=models.CASCADE)
    uploaded = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded']

    def __str__(self):
        return self.caption or "Untitled"

class Video(models.Model):
    video = models.FileField(upload_to='videos/')
    title = models.CharField(max_length=200)
    uploader = models.ForeignKey(User, on_delete=models.CASCADE)
    uploaded = models.DateTimeField(auto_now_add=True)
    thumbnail = models.ImageField(upload_to='video_thumbnails/', blank=True, null=True)  # ✅ added

    class Meta:
        ordering = ['-uploaded']

    def __str__(self):
        return self.title
EOF

# 🔴 NOTE: Reinsert unchanged views.py, admin.py, forms.py, and all templates from previous version EXCEPT:
# 🔴 REVISE the following files:
#   - views.py: add ffmpeg auto-thumbnail logic in upload_video()
#   - home.html: use poster="{{ video.thumbnail.url }}" on <video> tag


cat > $APP_NAME/views.py <<EOF
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.http import HttpResponse
from django.template.loader import render_to_string
from django.views.decorators.clickjacking import xframe_options_exempt
from .models import Article, Photo, Video
from .forms import ArticleForm, PhotoForm, VideoForm

# ✅ This function enables uploads for regular authenticated users in CKEditor
def custom_ckeditor_upload_permission(request):
    return request.user.is_authenticated

def home(request):
    articles = Article.objects.select_related('author').all()
    paginator = Paginator(articles, 5)
    page = request.GET.get('page')
    articles_page = paginator.get_page(page)
    videos = Video.objects.select_related('uploader').all()[:6]
    photos = Photo.objects.select_related('uploader').all()[:12]
    return render(request, 'entertainment/home.html', {
    'articles': articles_page,
    'photos': photos,
    'videos': videos
})

def article_detail(request, pk):
    article = get_object_or_404(Article, pk=pk)
    return render(request, 'entertainment/article_detail.html', {'article': article})

@xframe_options_exempt  # ✅ Allow iframe embedding for this route
def article_snippet(request, pk):
    article = get_object_or_404(Article, pk=pk)
    html = render_to_string('entertainment/article_snippet.html', {'article': article})
    return HttpResponse(html)

@login_required
def upload_video(request):
    if request.method == 'POST':
        form = VideoForm(request.POST, request.FILES)
        if form.is_valid():
            video = form.save(commit=False)
            video.uploader = request.user
            video.save()

            # ✅ Generate default thumbnail using ffmpeg if not uploaded
            if not video.thumbnail and video.video:
                import os, subprocess
                from django.conf import settings
                from django.core.files.base import ContentFile

                video_path = video.video.path
                thumb_dir = os.path.join(settings.MEDIA_ROOT, 'video_thumbnails')
                thumb_path = os.path.join(thumb_dir, f'thumb_{video.pk}.jpg')
                os.makedirs(thumb_dir, exist_ok=True)

                subprocess.run([
                    'ffmpeg', '-i', video_path, '-ss', '00:00:01.000', '-vframes', '1',
                    '-vf', 'scale=320:-1', thumb_path
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                if os.path.exists(thumb_path):
                    with open(thumb_path, 'rb') as f:
                        video.thumbnail.save(f'thumb_{video.pk}.jpg', ContentFile(f.read()), save=False)
            video.save()
            messages.success(request, 'Video uploaded successfully!')
            return redirect('home')
    else:
        form = VideoForm()
    return render(request, 'entertainment/upload_video.html', {'form': form})

@login_required
def delete_video(request, pk):
    video = get_object_or_404(Video, pk=pk)
    if request.user == video.uploader:
        video.delete()
        messages.success(request, 'Video deleted.')
    return redirect('home')


@login_required
def submit_article(request):
    if request.method == 'POST':
        form = ArticleForm(request.POST, request.FILES)
        if form.is_valid():
            article = form.save(commit=False)
            article.author = request.user
            article.save()
            messages.success(request, 'Article submitted successfully!')
            return redirect('home')
    else:
        form = ArticleForm()
    return render(request, 'entertainment/submit_article.html', {'form': form})

@login_required
def upload_photo(request):
    if request.method == 'POST':
        form = PhotoForm(request.POST, request.FILES)
        if form.is_valid():
            photo = form.save(commit=False)
            photo.uploader = request.user
            photo.save()
            messages.success(request, 'Photo uploaded successfully!')
            return redirect('home')
    else:
        form = PhotoForm()
    return render(request, 'entertainment/upload_photo.html', {'form': form})
    # Add edit and delete views for Article and Photo


@login_required
def edit_article(request, pk):
    article = get_object_or_404(Article, pk=pk)
    if request.user != article.author:
        return redirect('home')
    if request.method == 'POST':
        form = ArticleForm(request.POST, request.FILES, instance=article)
        if form.is_valid():
            form.save()
            messages.success(request, 'Article updated successfully!')
            return redirect('article_detail', pk=article.pk)
    else:
        form = ArticleForm(instance=article)
    return render(request, 'entertainment/submit_article.html', {'form': form})

@login_required
def delete_article(request, pk):
    article = get_object_or_404(Article, pk=pk)
    if request.user == article.author:
        article.delete()
        messages.success(request, 'Article deleted.')
    return redirect('home')

@login_required
def delete_photo(request, pk):
    photo = get_object_or_404(Photo, pk=pk)
    if request.user == photo.uploader:
        photo.delete()
        messages.success(request, 'Photo deleted.')
    return redirect('home')
EOF
# entertainment/urls.py
cat > $APP_NAME/urls.py <<EOF
from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
    path('submit/', views.submit_article, name='submit_article'),
    path('upload/', views.upload_photo, name='upload_photo'),
    path('upload-video/', views.upload_video, name='upload_video'),
    path('article/<int:pk>/', views.article_detail, name='article_detail'),
    path('article/<int:pk>/edit/', views.edit_article, name='edit_article'),
    path('article/<int:pk>/delete/', views.delete_article, name='delete_article'),
    path('article-snippet/<int:pk>/', views.article_snippet, name='article_snippet'),
    path('photo/<int:pk>/delete/', views.delete_photo, name='delete_photo'),
    path('video/<int:pk>/delete/', views.delete_video, name='delete_video'),
]
EOF


# New template for article_snippet.html

mkdir -p $APP_NAME/templates/entertainment
mkdir -p $APP_NAME/static/entertainment
# Create static folder and add placeholder banner
mkdir -p $APP_NAME/static/entertainment
curl -s -o $APP_NAME/static/entertainment/banner.jpg "https://placehold.co/728x90/cccccc/333333.png?text=Victoria+Live+Music+Banner" || echo "⚠️ Banner fallback failed — continuing"
cat > $APP_NAME/templates/entertainment/base.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Live Shows in Victoria</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
  <div class="container-fluid">
    <a class="navbar-brand" href="{% url 'home' %}">Live Shows in Victoria</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav ms-auto">
        {% if user.is_authenticated %}
          <li class="nav-item"><a class="nav-link" href="{% url 'submit_article' %}">Submit Article</a></li>
          <li class="nav-item"><a class="nav-link" href="{% url 'upload_photo' %}">Upload Photo</a></li>
          <li class="nav-item"><a class="nav-link" href="{% url 'upload_video' %}">Upload Video</a></li>
          <li class="nav-item"><a class="nav-link" href="{% url 'account_logout' %}">Logout ({{ user.username }})</a></li>
        {% else %}
          <li class="nav-item"><a class="nav-link" href="{% url 'account_login' %}">Login</a></li>
          <li class="nav-item"><a class="nav-link" href="{% url 'account_signup' %}">Sign Up</a></li>
        {% endif %}
      </ul>
    </div>
  </div>
</nav>
<div class="container">
    {% if messages %}
      {% for message in messages %}
        <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
          {{ message }}<button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      {% endfor %}
    {% endif %}
    {% block content %}{% endblock %}
</div>
<footer class="text-center mt-4 text-muted">&copy; {{ now|date:"Y" }} LiveShowSite</footer>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
{% block extra_scripts %}{% endblock %}
</body>
</html>
EOF



cat > $APP_NAME/templates/entertainment/article_snippet.html <<'EOF'
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title></title>
  <style>
    body {
      margin: 0;
      padding: 1rem;
      font-family: sans-serif;
      background-color: white;
      color: #222;
    }

    h5 {
      margin-bottom: 1rem;
      font-size: 1.25rem;
      font-weight: bold;
    }

    img {
      max-width: 100%;
      height: auto;
      margin: 1rem 0;
      display: block;
    }

    iframe, script, style {
      max-width: 100%;
    }
  </style>
</head>
<body>
  <h5>{{ article.title }}</h5>
  <div>
    {{ article.content|striptags|truncatewords:10|safe|cut:"&nbsp;" }}
  </div>
</body>
</html>

EOF


# Modify home.html to use iframe
cat > $APP_NAME/templates/entertainment/home.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% load static %}
{% block content %}

<img src="{% static 'entertainment/banner.jpg' %}" alt="Banner" class="img-fluid mb-4">

<h2 class="text-center">Post Videos, Pics, and Write about the Victoria Live Music Scene!</h2>

<div class="row">
  <!-- Left Column: Articles -->
  <div class="col-md-3">
    <h3>Latest Articles</h3>
    {% for article in articles %}
      <div class="card mb-3">
        {% if article.image %}
          <img src="{{ article.image.url }}" class="card-img-top img-fluid" alt="{{ article.title }}" style="max-height: 200px; object-fit: cover;">
        {% endif %}
        <div class="card-body p-2">
          <iframe src="{% url 'article_snippet' article.pk %}" width="100%" height="150" frameborder="0" style="border: none;"></iframe>
          <a href="{% url 'article_detail' article.pk %}" class="btn btn-sm btn-outline-primary mt-2">Read More</a>
          {% if user == article.author %}
            <a href="{% url 'edit_article' article.pk %}" class="btn btn-sm btn-warning mt-2">Edit</a>
            <a href="{% url 'delete_article' article.pk %}" class="btn btn-sm btn-danger mt-2" onclick="return confirm('Delete this article?');">Delete</a>
          {% endif %}
          <p class="text-muted mt-2"><small>By {{ article.author.username }} on {{ article.created|date:"M d, Y" }}</small></p>
        </div>
      </div>
    {% empty %}
      <p>No articles yet.</p>
    {% endfor %}

    {% if articles.has_other_pages %}
    <nav>
      <ul class="pagination justify-content-center">
        {% if articles.has_previous %}
          <li class="page-item"><a class="page-link" href="?page={{ articles.previous_page_number }}">Previous</a></li>
        {% endif %}
        <li class="page-item disabled"><span class="page-link">Page {{ articles.number }} of {{ articles.paginator.num_pages }}</span></li>
        {% if articles.has_next %}
          <li class="page-item"><a class="page-link" href="?page={{ articles.next_page_number }}">Next</a></li>
        {% endif %}
      </ul>
    </nav>
    {% endif %}
  </div>

  <!-- Center Column: Videos -->
  <div class="col-md-6">
    <h3 class="text-center">Recent Videos</h3>
    {% for video in videos %}
      <div class="card mb-4">
        <div class="ratio ratio-16x9">
          <video controls class="w-100"
       {% if video.thumbnail %}
           poster="{{ video.thumbnail.url }}"
       {% endif %}>
  <source src="{{ video.video.url }}" type="video/mp4">
  Your browser does not support the video tag.
</video>
        </div>
        <div class="card-body p-2">
          <h5 class="card-title">{{ video.title }}</h5>
          <small class="text-muted">By {{ video.uploader.username }} on {{ video.uploaded|date:"M d, Y" }}</small>
          {% if user == video.uploader %}
            <div class="mt-2">
              <a href="{% url 'delete_video' video.pk %}" class="btn btn-sm btn-danger" onclick="return confirm('Delete this video?');">Delete Video</a>
            </div>
          {% endif %}
        </div>
      </div>
    {% empty %}
      <p>No videos yet.</p>
    {% endfor %}
  </div>

  <!-- Right Column: Photos -->
  <div class="col-md-3">
    <h3>Recent Photos</h3>
    {% for photo in photos %}
      <div class="card mb-3">
        <img src="{{ photo.image.url }}" class="card-img-top img-fluid" alt="{{ photo.caption }}" style="max-height: 200px; object-fit: cover;">
        <div class="card-body p-2">
          <p class="card-text">{{ photo.caption }}</p>
          <small class="text-muted">By {{ photo.uploader.username }} on {{ photo.uploaded|date:"M d, Y" }}</small>
          {% if user == photo.uploader %}
            <div class="mt-2">
              <a href="{% url 'delete_photo' photo.pk %}" class="btn btn-sm btn-danger" onclick="return confirm('Delete this photo?');">Delete Photo</a>
            </div>
          {% endif %}
        </div>
      </div>
    {% empty %}
      <p>No photos yet.</p>
    {% endfor %}
  </div>
</div>
{% endblock %}
EOF
cat > $APP_NAME/templates/entertainment/article_detail.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-md-10">
    <h2>{{ article.title }}</h2>
    <p><small>By {{ article.author.username }} on {{ article.created|date:"M d, Y" }}</small></p>
    {% if article.image %}
      <img src="{{ article.image.url }}" class="img-fluid mb-3" alt="{{ article.title }}">
    {% endif %}
    <p>{{ article.content|safe }}</p>
    <a href="{% url 'home' %}" class="btn btn-secondary mt-3">← Back to Home</a>
  </div>
</div>
{% endblock %}
EOF

cat > $APP_NAME/templates/entertainment/submit_article.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-md-8">
    <h2>Submit Article</h2>
    <form method="post" enctype="multipart/form-data">
      {% csrf_token %}
      {{ form.media }}
      {% for field in form %}
        <div class="mb-3">
          {{ field.label_tag }} {{ field }}
          {% if field.help_text %}
            <small class="form-text text-muted">{{ field.help_text }}</small>
          {% endif %}
          {% for error in field.errors %}
            <div class="text-danger">{{ error }}</div>
          {% endfor %}
        </div>
      {% endfor %}
      <button type="submit" class="btn btn-primary">Submit</button>
      <a href="{% url 'home' %}" class="btn btn-secondary">Cancel</a>
    </form>
  </div>
</div>
{% endblock %}
EOF

cat > $APP_NAME/templates/entertainment/upload_photo.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-md-8">
    <h2>Upload Photo</h2>
    <form method="post" enctype="multipart/form-data">
      {% csrf_token %}
      {{ form.as_p }}
      <button type="submit" class="btn btn-success">Upload</button>
      <a href="{% url 'home' %}" class="btn btn-secondary">Cancel</a>
    </form>
  </div>
</div>
{% endblock %}
EOF

cat > $APP_NAME/templates/entertainment/upload_video.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-md-8">
    <h2>Upload Video</h2>
    <form method="post" enctype="multipart/form-data">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit" class="btn btn-success">Upload</button>
  <a href="{% url 'home' %}" class="btn btn-secondary">Cancel</a>
</form>
  </div>
</div>
{% endblock %}
EOF
cat > $APP_NAME/templates/entertainment/upload_video.html <<'EOF'
{% extends 'entertainment/base.html' %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-md-8">
    <h2>Upload Video</h2>
    <form method="post" enctype="multipart/form-data">
      {% csrf_token %}
      {{ form.as_p }}
      <button type="submit" class="btn btn-success">Upload</button>
      <a href="{% url 'home' %}" class="btn btn-secondary">Cancel</a>
    </form>
  </div>
</div>
{% endblock %}
EOF

# MIGRATE DATABASE
python manage.py makemigrations
python manage.py migrate

# CREATE SUPERUSER
python manage.py createsuperuser

# START DEV SERVER
python manage.py runserver
