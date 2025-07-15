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

