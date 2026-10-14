# 🚀 Staging Deployment Guide - staging.nduproject.com

## ✅ Deployment Preparation Complete

Your **NDU Project** is ready for world-class deployment to **staging.nduproject.com**!

---

## 📋 Project Overview

| Property | Value |
|----------|-------|
| **Framework** | Flutter 3.44.6 (FlutterFlow) |
| **Firebase Project** | `ndu-d3f60` |
| **Staging Target** | `staging` (channel: `staging-ndu`) |
| **Custom Domain** | `staging.nduproject.com` |
| **Build Output** | `build/web/` (ready) |

---

## 🔧 Deployment Options

### Option 1: GitHub Actions (Recommended - Automated)

The project has a pre-configured workflow that deploys to staging automatically:

```bash
# 1. Push to staging branch triggers automatic deployment
git push origin staging
```

**Workflow file:** `.github/workflows/deploy-staging.yml`

**Required GitHub Secrets:**
- `FIREBASE_SERVICE_ACCOUNT` - Firebase service account JSON
- `GITHUB_TOKEN` - Auto-provided by GitHub Actions

---

### Option 2: Manual Firebase CLI Deployment

#### Step 1: Authenticate with Firebase
```bash
# Login to Firebase (requires browser authentication)
firebase login

# Or use CI token for non-interactive
firebase login:ci
```

#### Step 2: Deploy to Staging
```bash
cd /home/z/my-project

# Set project
firebase use ndu-d3f60

# Deploy to staging target
firebase deploy \
  --only hosting:staging \
  --message "Deploy to staging $(date)"
```

#### Step 3: Configure Custom Domain
```bash
# Add custom domain to Firebase Hosting
firebase hosting:channel:deploy \
  staging-ndu \
  --expires 30d
```

Then in Firebase Console:
1. Go to **Hosting** → **Custom Domains**
2. Click **Add Custom Domain**
3. Enter: `staging.nduproject.com`
4. Follow DNS configuration steps

---

### Option 3: Using Deployment Scripts

We've created ready-to-use deployment scripts:

```bash
# Build script (if you need to rebuild)
./scripts/build_flutter.sh

# Deployment script
chmod +x scripts/deploy_staging.sh
./scripts/deploy_staging.sh
```

---

## 🌐 DNS Configuration (for staging.nduproject.com)

After Firebase deployment, configure your DNS:

### If using Cloudflare/Namecheap/etc:
| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | staging | ndu-d3f60.web.app. | Auto |

### If using Google Cloud DNS:
| Type | Name | Data | TTL |
|------|------|------|-----|
| CNAME | staging | c.storage.googleapis.com. | 3600 |

---

## ✅ Pre-Deployment Checklist

- [x] Flutter web build prepared in `build/web/`
- [x] CNAME configured for `staging.nduproject.com`
- [x] Firebase hosting target configured (`staging`)
- [x] Security headers configured (XSS, Frame Options, etc.)
- [x] Cache headers optimized (CSS/JS: 1hr, Fonts/WASM: 1yr)
- [x] SPA routing configured (rewrites to index.html)
- [ ] Firebase authentication configured ⚠️
- [ ] DNS records updated ⚠️
- [ ] SSL provisioned (automatic via Firebase) ⚠️

---

## 🔐 Security Configuration (Already Applied)

Your staging deployment includes enterprise-grade security:

```
✓ X-Content-Type-Options: nosniff
✓ X-Frame-Options: DENY  
✓ X-XSS-Protection: 1; mode=block
✓ Referrer-Policy: strict-origin-when-cross-origin
✓ Automatic SSL/TLS via Firebase
✓ Global CDN distribution
```

---

## 📊 Post-Deployment Verification

After deployment, verify:

1. **Main URL**: https://staging.nduproject.com
2. **Firebase URL**: https://ndu-d3f60.web.app/?channel=staging-ndu
3. **SSL Certificate**: Valid and issued for staging.nduproject.com
4. **SPA Routing**: All routes return index.html
5. **API Connectivity**: Firestore operations working
6. **Performance**: Lighthouse score > 90

---

## 🆘 Troubleshooting

### Issue: "Failed to authenticate"
```bash
# Re-authenticate
firebase logout
firebase login
```

### Issue: Custom domain not resolving
1. Check DNS propagation: `dig staging.nduproject.com`
2. Verify CNAME points to Firebase
3. Wait up to 24 hours for full propagation

### Issue: Build fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons
```

---

## 🎯 Next Steps

1. **Run Firebase login**: `firebase login`
2. **Execute deployment**: `./scripts/deploy_staging.sh`
3. **Configure DNS**: Add CNAME record for staging.nduproject.com
4. **Verify**: Open https://staging.nduproject.com

---

## 📞 Support

For issues:
- Firebase Console: https://console.firebase.google.com/project/ndu-d3f60/hosting
- GitHub Actions: https://github.com/CHAMA18/Ndu_Project/actions
- Documentation: See `/DEPLOYMENT_GUIDE.md`

---

**Deployment Status:** ✅ Ready for Authentication & Launch

**Last Updated:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')
