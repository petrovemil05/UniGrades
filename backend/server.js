import express from 'express';
import cors from 'cors';
import axios from 'axios';
import { wrapper } from 'axios-cookiejar-support';
import { CookieJar } from 'tough-cookie';
import dotenv from 'dotenv';

dotenv.config();

const app = express();

app.use(cors({
  origin: true,
  credentials: true
}));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const ESTUDENT_URL = process.env.ESTUDENT_URL || 'https://e-university.tu-sofia.bg/ETUS/studenti/index.php';
const SUSI_LOGIN_URL = process.env.SUSI_LOGIN_URL || 'https://susi.uni-sofia.bg/ISSU/forms/Login.aspx';
const SUSI_EXAMS_URL = process.env.SUSI_EXAMS_URL || 'https://susi.uni-sofia.bg/ISSU/forms/students/ReportExams.aspx';

function extractHiddenField(html, fieldId) {
  if (!html || typeof html !== 'string') return '';
  const tagRegex = new RegExp(`<input[^>]*\\b(?:id|name)=["']${fieldId}["'][^>]*>`, 'i');
  const tagMatch = html.match(tagRegex);
  if (!tagMatch) return '';
  const valueRegex = /value=["']([^"']*)["']/i;
  const valueMatch = tagMatch[0].match(valueRegex);
  if (!valueMatch) return '';
  return valueMatch[1]
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

app.post('/api/tu/grades', async (req, res) => {
  const { fnum, egn, deistvie = '1' } = req.body;

  if (!fnum || !egn) {
    return res.status(400).json({
      error: 'Липсва факултетен номер или ЕГН.'
    });
  }

  const jar = new CookieJar();
  const client = wrapper(axios.create({
    jar,
    withCredentials: true,
    maxRedirects: 5
  }));

  try {
    console.log('Logging in to E-Student...');

    const loginResponse = await client.post(
      ESTUDENT_URL,
      new URLSearchParams({
        fnum,
        egn
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    console.log('Login status:', loginResponse.status);
    console.log('Cookies after login:', await jar.getCookies(ESTUDENT_URL));

    console.log('Requesting grades...');

    const gradesResponse = await client.post(
      ESTUDENT_URL,
      new URLSearchParams({
        deistvie
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    const html = gradesResponse.data;

    console.log('Grades status:', gradesResponse.status);
    console.log('HTML length:', html.length);
    console.log('Contains оценки:', html.includes('оценк'));

    if (!html.includes('оценк')) {
      return res.status(401).type('text/html').send(
        '<html><body>INVALID_CREDENTIALS_OR_NO_SESSION</body></html>'
      );
    }

    res.type('text/html').send(html);
  } catch (error) {
    console.error('E-Student error:', error?.response?.status, error?.message);

    res.status(401).type('text/html').send(
      '<html><body>E_STUDENT_UNAVAILABLE</body></html>'
    );
  }
});

app.post('/api/su/grades', async (req, res) => {
  const username = req.body.username || req.body.fnum || req.body.user1;
  const password = req.body.password || req.body.egn || req.body.user2;

  if (!username || !password) {
    return res.status(400).json({
      error: 'Липсва потребителско име или парола за СУСИ.'
    });
  }

  const jar = new CookieJar();
  const client = wrapper(axios.create({
    jar,
    withCredentials: true,
    maxRedirects: 5,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    }
  }));

  try {
    console.log('Fetching SUSI login page...');
    const loginPageRes = await client.get(SUSI_LOGIN_URL);

    const vstate = extractHiddenField(loginPageRes.data, '__VSTATE');
    const viewState = extractHiddenField(loginPageRes.data, '__VIEWSTATE');
    const eventValidation = extractHiddenField(loginPageRes.data, '__EVENTVALIDATION');

    console.log('Posting credentials to SUSI...');
    const loginParams = new URLSearchParams({
      txtUserName: username,
      txtPassword: password,
      __VSTATE: vstate,
      __VIEWSTATE: viewState,
      __EVENTVALIDATION: eventValidation,
      btnSubmit: 'Влез',
    });

    const loginRes = await client.post(
      SUSI_LOGIN_URL,
      loginParams.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    const loginHtml = loginRes.data;
    if (typeof loginHtml === 'string' && loginHtml.includes('txtUserName') && loginHtml.includes('txtPassword')) {
      return res.status(401).type('text/html').send(
        '<html><body>INVALID_CREDENTIALS_OR_NO_SESSION</body></html>'
      );
    }

    console.log('Fetching SUSI exams page...');
    const examsPageRes = await client.get(SUSI_EXAMS_URL);

    const vstate2 = extractHiddenField(examsPageRes.data, '__VSTATE');
    const viewState2 = extractHiddenField(examsPageRes.data, '__VIEWSTATE');
    const eventValidation2 = extractHiddenField(examsPageRes.data, '__EVENTVALIDATION');

    console.log('Posting exams report request to SUSI...');
    const reportParams = new URLSearchParams({
      'Report_Exams1:chkTaken': 'on',
      'Report_Exams1:chkNotTaken': 'on',
      '__EVENTTARGET': 'Report_Exams1$btnReportExams',
      '__EVENTARGUMENT': '',
      '__VSTATE': vstate2,
      '__VIEWSTATE': viewState2,
      '__EVENTVALIDATION': eventValidation2,
    });

    const dataRes = await client.post(
      SUSI_EXAMS_URL,
      reportParams.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    const html = dataRes.data;
    console.log('SUSI response status:', dataRes.status);
    console.log('SUSI response length:', html?.length);

    res.type('text/html').send(html);
  } catch (error) {
    console.error('SUSI error:', error?.response?.status, error?.message);

    res.status(401).type('text/html').send(
      '<html><body>SUSI_UNAVAILABLE</body></html>'
    );
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log('UniGrades backend running on https://unigrades.bgsrv.eu');
});
