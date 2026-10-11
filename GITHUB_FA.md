# انتشار اولیه در گیت‌هاب

پوشهٔ اصلی مخزن باید همین `Codes/SKF_2025b` باشد، نه پوشهٔ مقاله‌ها و PDFها.

## ساخت مخزن خالی

در GitHub گزینهٔ New repository را انتخاب کنید:

- نام: `skf-bearing-life-calculator`
- توضیح: متن Description در README.
- Public یا Private مطابق ترجیح خودتان.
- Add README: غیرفعال؛ فایل محلی آماده است.
- Add .gitignore: None؛ فایل محلی آماده است.
- License: None فعلاً؛ مجوز باید آگاهانه انتخاب شود.

سپس Create repository را بزنید. این دستورها برای مخزن تازه و خالی هستند.

## اولین پوش از PowerShell

مقادیر نام، ایمیل و نام کاربری GitHub را با اطلاعات خودتان جایگزین کنید.
ایمیل می‌تواند ایمیل noreply حساب شما از Settings > Emails باشد.

```powershell
Set-Location -LiteralPath 'F:\LinkedIn\1st Week\1st; About L10 of Anti-friction\Codes\SKF_2025b'
git init -b main
git config user.name "YOUR NAME"
git config user.email "YOUR EMAIL"
git add .
git status
git commit -m "Initial release: MATLAB GUI and SKF chart data"
git remote add origin https://github.com/YOUR_USERNAME/skf-bearing-life-calculator.git
git push -u origin main
```

اگر مرورگر برای ورود باز شد، با حساب GitHub خود وارد شوید. برای احراز هویت
HTTPS از ورود مرورگر Git Credential Manager یا توکن استفاده می‌شود؛ رمز
عادی حساب GitHub برای git push قابل استفاده نیست.

## انتشار فایل اجرایی

فایل‌های اجرایی و ZIP در `.gitignore` حذف شده‌اند؛ آن‌ها را در بخش Releases
منتشر کنید. بعد از پوش کدها در صفحهٔ مخزن:

1. Releases > Draft a new release.
2. تگ جدید `v1.0.0`، شاخهٔ هدف `main`.
3. عنوان `SKF Bearing Life Calculator v1.0.0`.
4. فایل `dist/SKF_Bearing_Life_Windows_R2025b.zip` را پیوست کنید.
5. در توضیح بنویسید اجرای برنامه نیازمند MATLAB Runtime R2025b Windows 64-bit
   است و متلب یا مجوز متلب برای کاربر نهایی لازم نیست.
6. Publish release.

## تغییرات بعدی

```powershell
git add .
git commit -m "Describe the changes"
git push
```

منابع:

- https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
- https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
