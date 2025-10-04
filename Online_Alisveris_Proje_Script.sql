-- Online Alisveris Veritabani Scripti
-- (CREATE TABLE, INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, JOIN ve RAPORLAMA sorgulari dahil)
-- Hedef ortam: Microsoft SQL Server (SSMS / Azure Data Studio ile calistirilabilir)

/* 0) Veritabani olustur */
IF DB_ID('OnlineAlisveris') IS NULL
    CREATE DATABASE OnlineAlisveris;
GO
USE OnlineAlisveris;
GO

/* 1) Varsa tablolarin temizlenmesi (gelistirme icin) */
IF OBJECT_ID('dbo.Siparis_Detay','U') IS NOT NULL DROP TABLE dbo.Siparis_Detay;
IF OBJECT_ID('dbo.Siparis','U') IS NOT NULL DROP TABLE dbo.Siparis;
IF OBJECT_ID('dbo.Urun','U') IS NOT NULL DROP TABLE dbo.Urun;
IF OBJECT_ID('dbo.Kategori','U') IS NOT NULL DROP TABLE dbo.Kategori;
IF OBJECT_ID('dbo.Satici','U') IS NOT NULL DROP TABLE dbo.Satici;
IF OBJECT_ID('dbo.Musteri','U') IS NOT NULL DROP TABLE dbo.Musteri;
GO

/* 2) Tablolar */
CREATE TABLE dbo.Musteri (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ad NVARCHAR(50) NOT NULL,
    soyad NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    sehir NVARCHAR(50),
    kayit_tarihi DATE NOT NULL DEFAULT GETDATE()
);

CREATE TABLE dbo.Satici (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ad NVARCHAR(100) NOT NULL,
    adres NVARCHAR(200)
);

CREATE TABLE dbo.Kategori (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ad NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Urun (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ad NVARCHAR(100) NOT NULL,
    fiyat DECIMAL(10,2) NOT NULL CHECK (fiyat >= 0),
    stok INT NOT NULL CHECK (stok >= 0),
    kategori_id INT NOT NULL,
    satici_id INT NOT NULL,
    CONSTRAINT FK_Urun_Kategori FOREIGN KEY (kategori_id) REFERENCES dbo.Kategori(id),
    CONSTRAINT FK_Urun_Satici FOREIGN KEY (satici_id) REFERENCES dbo.Satici(id)
);

CREATE TABLE dbo.Siparis (
    id INT IDENTITY(1,1) PRIMARY KEY,
    musteri_id INT NOT NULL,
    tarih DATE NOT NULL DEFAULT GETDATE(),
    toplam_tutar DECIMAL(12,2) NOT NULL DEFAULT 0,
    odeme_turu NVARCHAR(30) NOT NULL, -- 'Kredi Karti', 'Kapida', 'Havale'...
    CONSTRAINT FK_Siparis_Musteri FOREIGN KEY (musteri_id) REFERENCES dbo.Musteri(id)
);

CREATE TABLE dbo.Siparis_Detay (
    id INT IDENTITY(1,1) PRIMARY KEY,
    siparis_id INT NOT NULL,
    urun_id INT NOT NULL,
    adet INT NOT NULL CHECK (adet > 0),
    fiyat DECIMAL(10,2) NOT NULL CHECK (fiyat >= 0), -- satisa o anki birim fiyat (snapshot)
    CONSTRAINT FK_SDetay_Siparis FOREIGN KEY (siparis_id) REFERENCES dbo.Siparis(id),
    CONSTRAINT FK_SDetay_Urun FOREIGN KEY (urun_id) REFERENCES dbo.Urun(id)
);
GO

/* 3) Ornek veriler */
INSERT INTO dbo.Kategori(ad) VALUES (N'Elektronik'),(N'Giyim'),(N'Ev & Yasam');
INSERT INTO dbo.Satici(ad, adres) VALUES (N'TechMarket', N'Istanbul'),(N'StyleHub', N'Ankara');
INSERT INTO dbo.Musteri(ad, soyad, email, sehir) VALUES
 (N'Aylin', N'Yilmaz', N'aylin@example.com', N'Istanbul'),
 (N'Emre',  N'Demir',  N'emre@example.com',  N'Ankara'),
 (N'Meryem',N'Eroz',   N'meryem@example.com',N'Istanbul');

INSERT INTO dbo.Urun(ad, fiyat, stok, kategori_id, satici_id) VALUES
 (N'Kulaklik',   750.00, 100, 1, 1),
 (N'Bluetooth Hoparlor', 1200.00, 50, 1, 1),
 (N'Tisort',      199.90, 200, 2, 2),
 (N'Koltuk',     5500.00,  10, 3, 2);
GO

/* 4) Stok azaltma triggeri: Siparis_Detay'a ekleme yapildiginda ilgili urunun stogu dusurulur */
IF OBJECT_ID('dbo.trg_StokAzalt','TR') IS NOT NULL DROP TRIGGER dbo.trg_StokAzalt;
GO
CREATE TRIGGER dbo.trg_StokAzalt
ON dbo.Siparis_Detay
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE u
    SET u.stok = u.stok - i.adet
    FROM dbo.Urun u
    JOIN inserted i ON u.id = i.urun_id;
END;
GO

/* 5) Ornek siparis ve detaylar (raporlar icin veri olussun) */
INSERT INTO dbo.Siparis(musteri_id, odeme_turu) VALUES (1, N'Kredi Karti'); -- Aylin
DECLARE @sip1 INT = SCOPE_IDENTITY();
INSERT INTO dbo.Siparis_Detay(siparis_id, urun_id, adet, fiyat) VALUES
 (@sip1, 1, 2, 750.00),     -- 2x Kulaklik
 (@sip1, 3, 1, 199.90);     -- 1x Tisort

INSERT INTO dbo.Siparis(musteri_id, odeme_turu) VALUES (3, N'Havale'); -- Meryem
DECLARE @sip2 INT = SCOPE_IDENTITY();
INSERT INTO dbo.Siparis_Detay(siparis_id, urun_id, adet, fiyat) VALUES
 (@sip2, 2, 1, 1200.00);    -- 1x Bluetooth Hoparlor

/* 5.a) Siparis toplamlarini guncelle (otomatik hesap) */
UPDATE s
SET toplam_tutar = x.toplam
FROM dbo.Siparis s
CROSS APPLY (
    SELECT SUM(adet * fiyat) AS toplam
    FROM dbo.Siparis_Detay d
    WHERE d.siparis_id = s.id
) x
WHERE s.id IN (@sip1, @sip2);

/* 6) CRUD ornekleri */
-- UPDATE: Urun fiyatini guncelle
UPDATE dbo.Urun SET fiyat = 725.00 WHERE ad = N'Kulaklik';

-- DELETE: Siparis vermemis musteriyi sil (ornek)
DELETE FROM dbo.Musteri
WHERE id NOT IN (SELECT DISTINCT musteri_id FROM dbo.Siparis);

-- TRUNCATE: Dikkat! Ornek olarak yorumlu birakildi
-- TRUNCATE TABLE dbo.Siparis_Detay;

/* 7) RAPORLAMA SORGULARI (12 adet) */

-- 1) En Cok Siparis Veren 5 Musteri
SELECT TOP 5 m.ad, m.soyad, COUNT(s.id) AS SiparisSayisi
FROM dbo.Musteri m
LEFT JOIN dbo.Siparis s ON s.musteri_id = m.id
GROUP BY m.ad, m.soyad
ORDER BY SiparisSayisi DESC;

-- 2) En Cok Satilan Urunler (Adet)
SELECT u.ad AS Urun, SUM(sd.adet) AS ToplamAdet
FROM dbo.Urun u
LEFT JOIN dbo.Siparis_Detay sd ON sd.urun_id = u.id
GROUP BY u.ad
ORDER BY ToplamAdet DESC;

-- 3) En Yuksek Ciroya Sahip Saticilar
SELECT sa.ad AS Satici, SUM(sd.adet * sd.fiyat) AS Ciro
FROM dbo.Satici sa
JOIN dbo.Urun u ON u.satici_id = sa.id
JOIN dbo.Siparis_Detay sd ON sd.urun_id = u.id
GROUP BY sa.ad
ORDER BY Ciro DESC;

-- 4) Sehirlere Gore Musteri Sayisi
SELECT sehir, COUNT(*) AS MusteriSayisi
FROM dbo.Musteri
GROUP BY sehir
ORDER BY MusteriSayisi DESC;

-- 5) Kategori Bazli Toplam Satis Cirosu
SELECT k.ad AS Kategori, SUM(sd.adet * sd.fiyat) AS Ciro
FROM dbo.Kategori k
JOIN dbo.Urun u ON u.kategori_id = k.id
JOIN dbo.Siparis_Detay sd ON sd.urun_id = u.id
GROUP BY k.ad
ORDER BY Ciro DESC;

-- 6) Aylara Gore Siparis Sayisi
SELECT FORMAT(s.tarih,'yyyy-MM') AS Ay, COUNT(*) AS SiparisSayisi
FROM dbo.Siparis s
GROUP BY FORMAT(s.tarih,'yyyy-MM')
ORDER BY Ay;

-- 7) Siparislerde Musteri + Urun + Satici Bilgisi (JOIN ornegi)
SELECT s.id AS SiparisID, m.ad + N' ' + m.soyad AS Musteri,
       u.ad AS Urun, sa.ad AS Satici, sd.adet, sd.fiyat, s.tarih
FROM dbo.Siparis s
JOIN dbo.Musteri m ON m.id = s.musteri_id
JOIN dbo.Siparis_Detay sd ON sd.siparis_id = s.id
JOIN dbo.Urun u ON u.id = sd.urun_id
JOIN dbo.Satici sa ON sa.id = u.satici_id
ORDER BY s.id;

-- 8) Hic Satilmamis Urunler
SELECT u.*
FROM dbo.Urun u
LEFT JOIN dbo.Siparis_Detay sd ON sd.urun_id = u.id
WHERE sd.id IS NULL;

-- 9) Hic Siparis Vermemis Musteriler
SELECT m.*
FROM dbo.Musteri m
LEFT JOIN dbo.Siparis s ON s.musteri_id = m.id
WHERE s.id IS NULL;

-- 10) En Cok Kazanc Saglayan Ilk 3 Kategori
SELECT TOP 3 k.ad AS Kategori, SUM(sd.adet * sd.fiyat) AS Ciro
FROM dbo.Kategori k
JOIN dbo.Urun u ON u.kategori_id = k.id
JOIN dbo.Siparis_Detay sd ON sd.urun_id = u.id
GROUP BY k.ad
ORDER BY Ciro DESC;

-- 11) Ortalama Siparis Tutarini Gecen Siparisler
WITH ort AS (
  SELECT AVG(toplam_tutar) AS ort_tutar FROM dbo.Siparis
)
SELECT s.*
FROM dbo.Siparis s CROSS JOIN ort
WHERE s.toplam_tutar > ort.ort_tutar
ORDER BY s.toplam_tutar DESC;

-- 12) En az bir kez Elektronik urun alan musteriler
SELECT DISTINCT m.id, m.ad, m.soyad, m.email
FROM dbo.Musteri m
JOIN dbo.Siparis s ON s.musteri_id = m.id
JOIN dbo.Siparis_Detay sd ON sd.siparis_id = s.id
JOIN dbo.Urun u ON u.id = sd.urun_id
WHERE u.kategori_id = (SELECT id FROM dbo.Kategori WHERE ad = N'Elektronik');

-- Bitti.
