var Station = require('../models/Station');

function StationController(){};

StationController.prototype.index = (async (req, res) => {
    try {
        res.render('index');
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.indexOne = (async (req, res) => {
    try {
        res.render('1/indexOne');
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.indexTwo = (async (req, res) => {
    try {
        res.render('2/indexTwo');
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.list = (async (req, res) => {
    try {
        const stations = await Station.find();
        res.json(stations.map(({ id }) => id));
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.view = (async (req, res) => {
    try {
        const stations = await Station.findOne({'id': req.params.id });
        res.json(stations);
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.update = (async (req, res) => {
    try {
        const stations = await Station.updateOne(
            {'id': req.params.id },
            {$set: { actual: req.body.actual, date: req.body.date } }
        );
        res.json(stations);
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.add = (async (req, res) => {
    const station = new Station({
        id: Math.floor(Math.random() * 10000) + 1,
        actual: Math.floor(Math.random() * 100) + 1,
        target: Math.floor(Math.random() * 100) + 1
    });
    try {
        const savedStation = await station.save();
        res.json(savedStation);
    } catch (err) {
        res.json({ message: err });
    }
});

StationController.prototype.delete = (async (req, res) => {
    try {
        const stations = await Station.deleteOne(
            {'id': req.params.id },
        );
        res.json(stations);
    } catch (err) {
        res.json({ message: err });
    }
});

module.exports = new StationController();