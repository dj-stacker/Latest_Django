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
